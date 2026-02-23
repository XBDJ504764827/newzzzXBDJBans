#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "3.5.0"

// 验证标准配置 (Removed hardcoded values, now fetched from DB per server)
// Player state arrays to hold DB config during async checks
bool g_bEnableVerification[MAXPLAYERS + 1];
bool g_bEnableWhitelist[MAXPLAYERS + 1];
float g_fMinRating[MAXPLAYERS + 1];
int g_iMinSteamLevel[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "zzzXBDJBans",
    author = "wwq",
    description = "CS:GO Ban System Integration",
    version = PLUGIN_VERSION,
    url = ""
};

Database g_hDatabase = null;
ConVar g_cvServerId;

public void OnPluginStart()
{
    g_cvServerId = CreateConVar("zzzxbdjbans_server_id", "1", "Server ID for this server instance");
    
    LogMessage("zzzXBDJBans Plugin v%s Loaded. Starting database connection...", PLUGIN_VERSION);
    Database.Connect(OnDatabaseConnected, "zzzXBDJBans");
    
    RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <duration_minutes> [reason]");
    RegAdminCmd("sm_unban", Command_Unban, ADMFLAG_BAN, "sm_unban <steamid|steamid64>");
    
    CreateTimer(60.0, Timer_CheckBans, _, TIMER_REPEAT);
}

public void OnDatabaseConnected(Database db, const char[] error, any data)
{
    if (db == null)
    {
        LogError("Failed to connect to zzzXBDJBans database: %s", error);
        return;
    }
    
    g_hDatabase = db;
    g_hDatabase.SetCharset("utf8mb4");
    LogMessage("Connected to zzzXBDJBans database successfully.");
}

public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client) || !g_hDatabase)
        return;

    // Reset state for new client
    g_bEnableVerification[client] = false;
    g_bEnableWhitelist[client] = false;
    g_fMinRating[client] = 0.0;
    g_iMinSteamLevel[client] = 0;

    StartVerification(client);
}

// ============================================
// 验证流程入口
// ============================================

void StartVerification(int client)
{
    char steamId[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId)))
    {
        KickClient(client, "验证错误：无效的SteamID");
        return;
    }

    // 检查服务器是否启用验证
    char query[256];
    Format(query, sizeof(query), "SELECT verification_enabled, enable_whitelist, min_rating, min_steam_level FROM servers WHERE id = %d", g_cvServerId.IntValue);
    g_hDatabase.Query(SQL_CheckVerificationEnabledCallback, query, GetClientUserId(client));
}

public void SQL_CheckVerificationEnabledCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;

    if (results == null)
    {
        LogError("Verification check failed (SQL error): %s", error);
        KickClient(client, "验证错误：数据库查询失败");
        return;
    }
    
    if (results.FetchRow())
    {
        g_bEnableVerification[client] = results.FetchInt(0) != 0;
        g_bEnableWhitelist[client] = results.FetchInt(1) != 0;
        g_fMinRating[client] = results.FetchFloat(2);
        g_iMinSteamLevel[client] = results.FetchInt(3);
    }
    else
    {
        LogMessage("Server ID %d not found in DB. Defaulting to no restrictions.", g_cvServerId.IntValue);
    }

    if (!g_bEnableVerification[client] && !g_bEnableWhitelist[client])
    {
        LogMessage("No verification or whitelist enabled for this server. Skipping for %N.", client);
        CheckBansAndAdmin(client);
        return;
    }

    // NEW LOGIC: Always check whitelist first if enabled
    if (g_bEnableWhitelist[client])
    {
        LogMessage("Whitelist enabled for this server. Checking for %N...", client);
        CheckWhitelist(client);
    }
    else if (g_bEnableVerification[client])
    {
        // Only verification enabled - Force fresh check per join
        LogMessage("Server is in Verification mode. Initializing fresh check for %N...", client);
        CreateVerificationRequest(client);
    }
}

// ============================================
// Step 1: 白名单检查（最优先）
// ============================================

void CheckWhitelist(int client)
{
    char steamId[64];
    char steamId2[64];
    
    GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
    GetClientAuthId(client, AuthId_Steam2, steamId2, sizeof(steamId2));
    
    char query[512];
    Format(query, sizeof(query), 
        "SELECT status FROM whitelist WHERE steam_id_64 = '%s' OR steam_id = '%s' OR steam_id = '%s'",
        steamId, steamId, steamId2);
    
    g_hDatabase.Query(SQL_CheckWhitelistCallback, query, GetClientUserId(client));
}

public void SQL_CheckWhitelistCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;

    if (results == null)
    {
        LogError("Whitelist check failed (SQL error): %s", error);
        KickClient(client, "验证错误：数据库查询失败");
        return;
    }

    if (results.FetchRow())
    {
        char status[32];
        results.FetchString(0, status, sizeof(status));

        if (StrEqual(status, "rejected"))
        {
            KickClient(client, "您已被拒绝访问本服务器");
            LogMessage("Player %N blocked (whitelist rejected).", client);
            return;
        }

        if (StrEqual(status, "approved"))
        {
            // 在白名单中且已通过，直接放行
            LogMessage("Player %N is in WHITELIST (APPROVED). Direct pass.", client);
            CheckBansAndAdmin(client);
            return;
        }
        
        // 如果开启了验证，则给第二次机会，且每次进入都重新验证
        if (g_bEnableVerification[client])
        {
            LogMessage("Player %N is not approved in whitelist. Starting fresh verification...", client);
            CreateVerificationRequest(client);
            return;
        }

        // 没有开启验证，则直接按照白名单处理结果
        if (StrEqual(status, "rejected"))
        {
            KickClient(client, "您已被拒绝访问本服务器");
        }
        else // pending
        {
            KickClient(client, "您的白名单申请正在审核中");
        }
    }
    else
    {
        // 不在白名单表中
        if (g_bEnableVerification[client])
        {
            LogMessage("Player %N not in whitelist. Starting fresh verification...", client);
            CreateVerificationRequest(client);
        }
        else
        {
            KickClient(client, "本服务器仅允许白名单玩家进入");
            LogMessage("Player %N blocked (not in whitelist).", client);
        }
    }
}

// ============================================
// Step 2: 创建验证请求，等待后端获取数据 (已跳过本地缓存检查)
// ============================================

void CreateVerificationRequest(int client)
{
    char steamId[64];
    char playerName[128];
    char ip[32];
    
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId))) return;
    GetClientName(client, playerName, sizeof(playerName));
    GetClientIP(client, ip, sizeof(ip));
    
    char escapedName[256];
    g_hDatabase.Escape(playerName, escapedName, sizeof(escapedName));
    
    char query[1024];
    Format(query, sizeof(query), 
        "INSERT INTO player_cache (steam_id, player_name, ip_address, status) VALUES ('%s', '%s', '%s', 'pending') ON DUPLICATE KEY UPDATE player_name='%s', ip_address='%s', status='pending', steam_level=NULL, gokz_rating=NULL, updated_at=NOW()", 
        steamId, escapedName, ip, escapedName, ip);
    
    g_hDatabase.Query(SQL_CreateRequestCallback, query, GetClientUserId(client));
}

public void SQL_CreateRequestCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;

    if (results == null)
    {
        LogError("Failed to create verification request (SQL error): %s", error);
        KickClient(client, "验证错误：数据库错误");
        return;
    }

    // 等待后端获取数据
    CreateTimer(1.5, Timer_PollVerification, userid);
}

public Action Timer_PollVerification(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client))
        return Plugin_Stop;

    PollVerificationResult(client);
    return Plugin_Stop;
}

void PollVerificationResult(int client)
{
    char steamId[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId))) return;

    char query[512];
    Format(query, sizeof(query), 
        "SELECT status, steam_level, gokz_rating FROM player_cache WHERE steam_id = '%s'", 
        steamId);
    
    g_hDatabase.Query(SQL_PollVerificationCallback, query, GetClientUserId(client));
}

public void SQL_PollVerificationCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;

    if (results == null)
    {
        LogError("Poll verification failed (SQL error): %s", error);
        KickClient(client, "验证错误：数据库查询失败");
        return;
    }

    if (!results.FetchRow())
    {
        LogError("Verification record not found for player %N", client);
        KickClient(client, "验证错误：记录不存在");
        return;
    }

    char status[32];
    results.FetchString(0, status, sizeof(status));
    
    if (StrEqual(status, "pending"))
    {
        // 后端还未处理，继续等待
        LogMessage("Player %N data still pending. Waiting...", client);
        CreateTimer(1.5, Timer_PollVerification, userid);
        return;
    }
    
    // 后端已获取数据 (status = 'verified')
    int level = 0;
    float rating = 0.0;
    
    if (!results.IsFieldNull(1))
    {
        level = results.FetchInt(1);
    }
    if (!results.IsFieldNull(2))
    {
        char ratingStr[32];
        results.FetchString(2, ratingStr, sizeof(ratingStr));
        rating = StringToFloat(ratingStr);
    }

    LogMessage("Player %N data received: Level=%d, Rating=%.2f", client, level, rating);
    
    // Step 4: 执行本地验证
    PerformVerification(client, level, rating);
}

// ============================================
// Step 4: 执行验证判断
// ============================================

void PerformVerification(int client, int level, float rating)
{
    char steamId[64];
    GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

    float reqRating = g_fMinRating[client];
    int reqLevel = g_iMinSteamLevel[client];

    bool passed = (rating >= reqRating && level >= reqLevel);
    char reason[256];

    if (passed)
    {
        Format(reason, sizeof(reason), "验证通过：Rating %.2f / 等级 %d", rating, level);
        LogMessage("Verification PASSED for %N: %s", client, reason);
        
        // 注意：这里不再写入 'allowed' 状态到数据库，确保下次进服依然触发重新查询
        CheckBansAndAdmin(client);
    }
    else
    {
        Format(reason, sizeof(reason), "验证失败：Rating %.2f(需>=%.1f) / 等级 %d(需>=%d)", 
            rating, reqRating, level, reqLevel);
        LogMessage("Verification DENIED for %N: %s", client, reason);
        
        // 删除缓存，不保存失败记录
        DeleteFromCache(steamId);
        
        KickClient(client, "%s", reason);
    }
}

// 已删除 UpdateCacheStatus 函数，因为我们不再缓存通过状态。

void DeleteFromCache(const char[] steamId)
{
    char query[256];
    Format(query, sizeof(query), 
        "DELETE FROM player_cache WHERE steam_id = '%s'",
        steamId);
    
    g_hDatabase.Query(SQL_GenericCallback, query);
}

public void SQL_GenericCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("SQL query failed: %s", error);
    }
}

// ============================================
// 封禁和管理员检查
// ============================================

void CheckBansAndAdmin(int client)
{
    char steamId[32];
    char steamIdOther[32];
    char ip[32];
    char steamId64[64];
    
    GetClientAuthId(client, AuthId_SteamID64, steamId64, sizeof(steamId64));
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    GetClientIP(client, ip, sizeof(ip));
    
    LogMessage("Checking bans for %N (SteamID: %s, IP: %s)", client, steamId64, ip);

    strcopy(steamIdOther, sizeof(steamIdOther), steamId);
    if (steamId[6] == '0') steamIdOther[6] = '1';
    else if (steamId[6] == '1') steamIdOther[6] = '0';
    
    // 1. Check Bans
    // Fetch ban_type (5) and steam_id_64 (6) from DB
    char query[1024];
    Format(query, sizeof(query), 
        "SELECT id, reason, duration, expires_at, ip, ban_type, steam_id_64 FROM bans WHERE (steam_id_64 = '%s' OR steam_id = '%s' OR steam_id = '%s' OR ip = '%s') AND status = 'active' AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1", 
        steamId64, steamId, steamIdOther, ip);
    
    g_hDatabase.Query(SQL_CheckBanCallback, query, GetClientUserId(client));
    
    // 2. Sync Admin (Disabled per requirement: Web admins do not get in-game privileges)
    // Format(query, sizeof(query), "SELECT role FROM admins WHERE steam_id_64 = '%s' OR steam_id = '%s' OR steam_id = '%s'", steamId64, steamId, steamIdOther);
    // g_hDatabase.Query(SQL_CheckAdminCallback, query, GetClientUserId(client));
}

public void SQL_CheckBanCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;
    
    if (results == null)
    {
        LogError("Ban check query failed: %s", error);
        return;
    }
    
    if (results.FetchRow())
    {
        int banId = results.FetchInt(0);
        char reason[128];
        char duration[32];
        char storedIp[32];
        char banType[32];
        char bannedSteamId64[64];
        
        results.FetchString(1, reason, sizeof(reason));
        results.FetchString(2, duration, sizeof(duration));
        results.FetchString(4, storedIp, sizeof(storedIp));
        results.FetchString(5, banType, sizeof(banType));
        results.FetchString(6, bannedSteamId64, sizeof(bannedSteamId64));
        
        char clientSteamId64[64];
        char clientIp[32];
        GetClientAuthId(client, AuthId_SteamID64, clientSteamId64, sizeof(clientSteamId64));
        GetClientIP(client, clientIp, sizeof(clientIp));

        // 判断是否是本人 (SteamID 匹配)
        bool isSameAccount = StrEqual(clientSteamId64, bannedSteamId64);

        if (isSameAccount)
        {
            // Case A: 同账号匹配 (Direct Ban)
            // 如果数据库中没有 IP 记录，更新为当前玩家 IP
            if (storedIp[0] == '\0')
            {
                char updateQuery[256];
                Format(updateQuery, sizeof(updateQuery), "UPDATE bans SET ip = '%s' WHERE id = %d", clientIp, banId);
                g_hDatabase.Query(SQL_GenericCallback, updateQuery);
                LogMessage("Updated missing IP for banned player %N (BanID: %d, IP: %s)", client, banId, clientIp);
            }
            // 踢出
            KickClient(client, "您已被封禁。原因：%s（时长：%s）", reason, duration);
            LogMessage("Kicked banned player: %N (Account Match, BanID: %d)", client, banId);
        }
        else
        {
            // Case B: 异账号匹配 (IP Match)
            if (StrEqual(banType, "ip"))
            {
                // 是 IP 封禁 -> 连坐
                LogMessage("IP Ban Match for %N! (Linked to BanID: %d, IP: %s)", client, banId, clientIp);

                // 为当前马甲号创建新封禁
                char newReason[256];
                Format(newReason, sizeof(newReason), "同IP关联封禁 (Linked to %s)", bannedSteamId64);
                
                char insertQuery[1024];
                Format(insertQuery, sizeof(insertQuery), 
                    "INSERT INTO bans (name, steam_id, steam_id_64, ip, ban_type, reason, duration, admin_name, expires_at, created_at, status, server_id) SELECT '%N', 'PENDING', '%s', '%s', 'account', '%s', duration, 'System (IP Linked)', expires_at, NOW(), 'active', server_id FROM bans WHERE id = %d",
                    client, clientSteamId64, clientIp, newReason, banId);
                
                g_hDatabase.Query(SQL_GenericCallback, insertQuery);

                KickClient(client, "检测到关联封禁 IP。在此 IP 上的所有账号均被禁止进入。");
            }
            else
            {
                // 不是 IP 封禁 -> 放行
                LogMessage("Player %N shares IP with banned player (BanID: %d) but BanType is '%s'. ALLOWING access.", client, banId, banType);
                // 不执行 KickClient，直接返回
            }
        }
    }
}

public void SQL_CheckAdminCallback(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0) return;
    
    if (results == null)
    {
        LogError("Admin check query failed: %s", error);
        return;
    }
    
    if (results.FetchRow())
    {
        char role[32];
        results.FetchString(0, role, sizeof(role));
        
        AdminId admin = CreateAdmin("TempAdmin");
        if (StrEqual(role, "super_admin"))
        {
            admin.SetFlag(Admin_Root, true);
        }
        else if (StrEqual(role, "admin"))
        {
            admin.SetFlag(Admin_Generic, true);
            admin.SetFlag(Admin_Kick, true);
            admin.SetFlag(Admin_Ban, true);
        }
        
        SetUserAdmin(client, admin, true);
        LogMessage("Granted admin privileges to %N (%s)", client, role);
    }
}

// ============================================
// 定时检查封禁
// ============================================

public Action Timer_CheckBans(Handle timer)
{
    if (!g_hDatabase) return Plugin_Continue;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            CheckBansAndAdmin(i);
        }
    }
    return Plugin_Continue;
}

// ============================================
// 封禁命令实现
// ============================================

public Action Command_Ban(int client, int args)
{
    if (!g_hDatabase)
    {
        ReplyToCommand(client, "[zzzXBDJBans] 数据库未连接，无法执行封禁。");
        return Plugin_Handled;
    }

    if (args < 2)
    {
        ReplyToCommand(client, "[zzzXBDJBans] 用法: sm_ban <#userid|name> <duration_minutes> [reason]");
        return Plugin_Handled;
    }

    char targetStr[64], durationStr[32], reason[256];
    GetCmdArg(1, targetStr, sizeof(targetStr));
    GetCmdArg(2, durationStr, sizeof(durationStr));
    
    if (args >= 3)
    {
        GetCmdArgString(reason, sizeof(reason));
        // 跳过目标和时长的部分
        int firstChar = 0;
        int argCount = 0;
        for (int i = 0; reason[i] != '\0'; i++)
        {
            if (reason[i] == ' ' && ++argCount == 2)
            {
                firstChar = i + 1;
                break;
            }
        }
        if (firstChar > 0) strcopy(reason, sizeof(reason), reason[firstChar]);
    }
    else
    {
        strcopy(reason, sizeof(reason), "管理员执行封禁");
    }

    int target = FindTarget(client, targetStr, true, true);
    if (target == -1) return Plugin_Handled;

    char steamId64[64], steamId2[32], targetName[MAX_NAME_LENGTH], targetIp[45];
    if (!GetClientAuthId(target, AuthId_SteamID64, steamId64, sizeof(steamId64)))
    {
        ReplyToCommand(client, "[zzzXBDJBans] 无法获取目标的 SteamID64");
        return Plugin_Handled;
    }
    GetClientAuthId(target, AuthId_Steam2, steamId2, sizeof(steamId2));
    GetClientName(target, targetName, sizeof(targetName));
    GetClientIP(target, targetIp, sizeof(targetIp));

    char adminName[MAX_NAME_LENGTH];
    if (client == 0) strcopy(adminName, sizeof(adminName), "Console");
    else GetClientName(client, adminName, sizeof(adminName));

    int duration = StringToInt(durationStr);

    char escapedName[MAX_NAME_LENGTH * 2 + 1], escapedReason[sizeof(reason) * 2 + 1], escapedAdmin[MAX_NAME_LENGTH * 2 + 1];
    g_hDatabase.Escape(targetName, escapedName, sizeof(escapedName));
    g_hDatabase.Escape(reason, escapedReason, sizeof(escapedReason));
    g_hDatabase.Escape(adminName, escapedAdmin, sizeof(escapedAdmin));

    char query[1024];
    if (duration > 0)
    {
        Format(query, sizeof(query), 
            "INSERT INTO bans (name, steam_id, steam_id_64, ip, ban_type, reason, duration, expires_at, admin_name, server_id, status) VALUES ('%s', '%s', '%s', '%s', 'account', '%s', '%d', DATE_ADD(NOW(), INTERVAL %d MINUTE), '%s', %d, 'active')",
            escapedName, steamId2, steamId64, targetIp, escapedReason, duration, duration, escapedAdmin, g_cvServerId.IntValue);
    }
    else
    {
        Format(query, sizeof(query), 
            "INSERT INTO bans (name, steam_id, steam_id_64, ip, ban_type, reason, duration, expires_at, admin_name, server_id, status) VALUES ('%s', '%s', '%s', '%s', 'account', '%s', '0', NULL, '%s', %d, 'active')",
            escapedName, steamId2, steamId64, targetIp, escapedReason, escapedAdmin, g_cvServerId.IntValue);
    }

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(target));
    pack.WriteString(targetName);
    pack.WriteString(reason);
    pack.WriteCell(duration);

    g_hDatabase.Query(SQL_BanInsertedCallback, query, pack);
    
    ReplyToCommand(client, "[zzzXBDJBans] 正在封禁玩家 %s...", targetName);
    return Plugin_Handled;
}

public void SQL_BanInsertedCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    char targetName[MAX_NAME_LENGTH], reason[256];
    pack.ReadString(targetName, sizeof(targetName));
    pack.ReadString(reason, sizeof(reason));
    int duration = pack.ReadCell();
    delete pack;

    if (db == null || results == null)
    {
        LogError("Failed to insert ban into DB: %s", error);
        return;
    }

    int target = GetClientOfUserId(userid);
    if (target != 0)
    {
        char durationStr[32];
        if (duration == 0) strcopy(durationStr, sizeof(durationStr), "永久");
        else Format(durationStr, sizeof(durationStr), "%d 分钟", duration);

        KickClient(target, "您已被封禁。原因: %s (时长: %s)", reason, durationStr);
    }

    PrintToChatAll(" \x04[zzzXBDJBans]\x01 管理员封禁了玩家 \x07%s\x01。原因: %s", targetName, reason);
}

// ============================================
// 解封命令实现
// ============================================

public Action Command_Unban(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[zzzXBDJBans] 用法: sm_unban <steamid|steamid64>");
        return Plugin_Handled;
    }

    char targetAuth[64];
    GetCmdArg(1, targetAuth, sizeof(targetAuth));

    if (g_hDatabase == null)
    {
        ReplyToCommand(client, "[zzzXBDJBans] 数据库未连接");
        return Plugin_Handled;
    }

    char query[512];
    Format(query, sizeof(query), 
        "UPDATE bans SET status = 'unbanned' WHERE (steam_id = '%s' OR steam_id_64 = '%s') AND status = 'active'", 
        targetAuth, targetAuth);
    
    DataPack pack = new DataPack();
    pack.WriteCell(client != 0 ? GetClientUserId(client) : 0);
    pack.WriteString(targetAuth);

    g_hDatabase.Query(SQL_UnbanCallback, query, pack);
    return Plugin_Handled;
}

public void SQL_UnbanCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int adminUserid = pack.ReadCell();
    char targetAuth[64];
    pack.ReadString(targetAuth, sizeof(targetAuth));
    delete pack;

    int admin = adminUserid == 0 ? 0 : GetClientOfUserId(adminUserid);

    if (db == null || results == null)
    {
        if (admin != 0 || adminUserid == 0) ReplyToCommand(admin, "[zzzXBDJBans] 解封失败: %s", error);
        return;
    }

    if (results.AffectedRows > 0)
    {
        ReplyToCommand(admin, "[zzzXBDJBans] 已解封玩家: %s", targetAuth);
        PrintToChatAll(" \x04[zzzXBDJBans]\x01 管理员解封了玩家 \x07%s\x01。", targetAuth);
    }
    else
    {
        ReplyToCommand(admin, "[zzzXBDJBans] 未找到该玩家的活跃封禁记录: %s", targetAuth);
    }
}
