import { ref, computed } from 'vue'
import api from '../utils/api'

// Global state
const serverGroups = ref<any[]>([])

export const useCommunityStore = () => {

    // Fetch
    const fetchServerGroups = async () => {
        try {
            const res = await api.get('/server-groups')
            if (Array.isArray(res.data)) {
                serverGroups.value = res.data.map((g: any) => ({
                    ...g,
                    servers: (g.servers || []).map((s: any) => ({
                        ...s,
                        status: 'unknown'
                    }))
                }))
            } else {
                console.warn('Unexpected server-groups data format:', res.data)
                serverGroups.value = []
            }

            checkAllStatuses()
        } catch (e) {
            console.error(e)
            serverGroups.value = []
        }
    }

    const checkAllStatuses = async () => {
        for (const group of serverGroups.value) {
            for (const server of group.servers) {
                checkOneServerStatus(group.id, server)
            }
        }
    }

    const checkOneServerStatus = async (groupId: number | string, server: any) => {
        try {
            await api.post('/servers/check', {
                ip: server.ip,
                port: server.port,
                rcon_password: server.rcon_password
            })
            updateLocalStatus(groupId, server.id, 'online')
        } catch (e) {
            updateLocalStatus(groupId, server.id, 'offline')
        }
    }

    const updateLocalStatus = (groupId: number | string, serverId: number | string, status: string) => {
        const group = serverGroups.value.find(g => g.id === groupId)
        if (group) {
            const s = group.servers.find((s: any) => s.id === serverId)
            if (s) s.status = status
        }
    }

    const addServerGroup = async (name: string) => {
        try {
            await api.post('/server-groups', { name })
            await fetchServerGroups()
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '创建失败' }
        }
    }

    const removeServerGroup = async (groupId: number | string) => {
        try {
            await api.delete(`/server-groups/${groupId}`)
            await fetchServerGroups()
            return { success: true }
        } catch (e) {
            return { success: false, message: '删除失败' }
        }
    }

    const addServer = async (groupId: number | string, serverData: any) => {
        try {
            await api.post('/servers', { group_id: groupId, ...serverData })
            await fetchServerGroups()
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '添加失败' }
        }
    }

    const updateServer = async (_groupId: number | string, serverId: number | string, serverData: any) => {
        try {
            await api.put(`/servers/${serverId}`, serverData)
            await fetchServerGroups()
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '更新失败' }
        }
    }

    const removeServer = async (_groupId: number | string, serverId: number | string) => {
        try {
            await api.delete(`/servers/${serverId}`)
            await fetchServerGroups()
            return { success: true }
        } catch (e) {
            return { success: false, message: '删除失败' }
        }
    }

    const checkServer = async (connectionInfo: any) => {
        try {
            await api.post('/servers/check', connectionInfo)
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '连接失败' }
        }
    }

    const fetchPlayers = async (serverId: number | string) => {
        try {
            const res = await api.get(`/servers/${serverId}/players`)
            return { success: true, data: res.data }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '获取玩家列表失败' }
        }
    }

    const kickPlayer = async (serverId: number | string, userid: number | string, reason: string) => {
        try {
            await api.post(`/servers/${serverId}/kick`, { userid, reason })
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '踢出失败' }
        }
    }

    const banPlayer = async (serverId: number | string, userid: number | string, duration: number, reason: string, ban_type: string) => {
        try {
            await api.post(`/servers/${serverId}/ban`, { userid, duration, reason, ban_type })
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '封禁失败' }
        }
    }

    const hasCommunity = computed(() => serverGroups.value.length > 0)

    return {
        serverGroups,
        hasCommunity,
        fetchServerGroups,
        addServerGroup,
        removeServerGroup,
        addServer,
        updateServer,
        removeServer,
        checkServer,
        fetchPlayers,
        kickPlayer,
        banPlayer
    }
}
