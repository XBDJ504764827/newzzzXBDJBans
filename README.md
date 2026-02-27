# zzzXBDJBans 项目部署指南

本项目是一个集前端管理网页、后端 API 服务及 CSGO 游戏内插件于一体的综合禁封与白名单管理系统。

## 1. 架构说明
- **后端 (zzzXBDJBansBackend)**: 使用 Rust (Axum) 开发，负责权限鉴权、白名单逻辑处理及日志审计。
- **前端 (zzzXBDJBansWebPro)**: 使用 Vue 3 + Vite + Ant Design Vue 开发，提供直观的管理后台。
- **插件 (zzzXBDJBansCsgoInprop)**: SourceMod 插件，实现游戏内封禁执行及进服验证逻辑。
- **数据库**: MySQL 5.7+。

---

## 2. 后端部署 (Rust)

### 环境要求
- Rust 1.70+
- MySQL 数据库

### 构建与运行
1. 进入后端目录：`cd zzzXBDJBansBackend`
2. 配置环境变量：创建 `.env` 文件并填入：
   ```env
   DATABASE_URL=mysql://用户名:密码@主机/数据库名
   SERVER_HOST=0.0.0.0
   SERVER_PORT=3000
   JWT_SECRET=请设置高强度随机密钥
   CORS_ALLOWED_ORIGINS=http://localhost:5173
   STEAM_API_KEY=你的SteamAPIKey
   ```
3. 构建：`cargo build --release`
4. 运行：`./target/release/zzzXBDJBansBackend`
   - *首次运行会自动执行数据库迁移。*

---

## 3. 前端部署 (Vue 3)

### 环境要求
- Node.js 16+
- npm 或 yarn

### 构建与部署
1. 进入前端目录：`cd zzzXBDJBansWebPro`
2. 安装依赖：`npm install`
3. 修改配置：在 `src/utils/api.ts` 或环境变量中设置后端地址。
4. 开发模式：`npm run dev`
5. 生成生产包：`npm run build`
   - 构建产物位于 `dist` 目录，建议使用 Nginx 进行托管。

---

## 4. CSGO 插件安装 (SourceMod)

### 环境要求
- SourceMod 1.11+

### 配置方法
1. **数据库配置**:
   - 编辑服务器 `addons/sourcemod/configs/databases.cfg`，添加以下内容：
     ```text
     "zzzXBDJBans"
     {
         "driver"            "mysql"
         "host"              "你的数据库主机"
         "database"          "zzzXBDJBans"
         "user"              "用户名"
         "pass"              "密码"
         "port"              "3306"
     }
     ```
2. **插件编译**:
   - 将 `zzzXBDJBans.sp` 放入 `scripting` 目录。
   - 使用 `spcomp zzzXBDJBans.sp` 编译得到 `.smx` 文件。
3. **部署**:
   - 将编译好的 `zzzXBDJBans.smx` 放入 `plugins` 目录。
4. **服务器参数**:
   - 在 `server.cfg` 中添加：`zzzxbdjbans_server_id "1"` (确保 ID 在后台服务器管理中唯一)。

---

## 5. 关键功能说明
- **自动化验证**: 后端 worker 会自动获取玩家的 Steam 等级及 GOKZ Rating。
- **全局封禁库**: 系统支持通过后端的 `/api/check_global_ban/bulk` 接口代理查询 GOKZ 全局封禁状态。
- **操作审计**: 所有的管理员操作均会记录在 `audit_logs` 表中。
- **管理端列表分页**: `/api/bans`、`/api/admins`、`/api/whitelist`、`/api/whitelist/pending`、`/api/whitelist/rejected` 统一返回分页结构：`{ items, total, page, page_size }`。
