import { ref } from 'vue'
import api from '../utils/api'

// State
const logs = ref<any[]>([])

export const useLogStore = () => {

    const mapLogFromBackend = (l: any) => ({
        id: l.id,
        time: l.created_at,
        admin: l.admin_username,
        action: l.action,
        target: l.target,
        details: l.details
    })

    const fetchLogs = async () => {
        try {
            const res = await api.get('/logs')
            logs.value = res.data.map(mapLogFromBackend)
        } catch (e) {
            console.error(e)
        }
    }

    const addLog = async ({ admin, action, target, details }: any) => {
        try {
            await api.post('/logs', {
                admin_username: admin,
                action,
                target,
                details
            })
        } catch (e) {
            console.error("Failed to log", e)
        }
    }

    const clearLogs = () => {
        logs.value = []
    }

    return {
        logs,
        fetchLogs,
        addLog,
        clearLogs
    }
}
