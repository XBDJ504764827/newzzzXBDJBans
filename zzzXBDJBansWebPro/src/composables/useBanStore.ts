import { ref } from 'vue'
import api from '../utils/api'

// Global state
const bans = ref([])
const publicBans = ref([])
const bansTotal = ref(0)
const bansPage = ref(1)
const bansPageSize = ref(15)

export const useBanStore = () => {

    const fetchBans = async (page = bansPage.value, pageSize = bansPageSize.value) => {
        try {
            const res = await api.get('/bans', { params: { page, page_size: pageSize } })
            bans.value = res.data.items
            bansTotal.value = res.data.total
            bansPage.value = res.data.page
            bansPageSize.value = res.data.page_size
        } catch (e) {
            console.error(e)
        }
    }

    const fetchPublicBans = async () => {
        try {
            const res = await api.get('/bans/public')
            publicBans.value = res.data
        } catch (e) {
            console.error(e)
        }
    }

    const addBan = async (banData: any) => {
        try {
            const payload = {
                name: banData.name,
                steam_id: banData.steamId,
                ip: banData.ip,
                ban_type: banData.banType,
                reason: banData.reason,
                duration: banData.duration,
                admin_name: banData.adminName
            }
            await api.post('/bans', payload)
            await fetchBans()
            return { success: true }
        } catch (e: any) {
            console.error(e)
            return { success: false, message: e.response?.data || 'Failed' }
        }
    }

    const removeBan = async (id: number | string) => {
        try {
            await api.put(`/bans/${id}`, { status: 'unbanned' })
            await fetchBans()
            return true
        } catch (e) {
            console.error(e)
            return false
        }
    }

    const updateBan = async (id: number | string, updatedData: any) => {
        try {
            const payload: any = {}
            if (updatedData.status) payload.status = updatedData.status
            if (updatedData.name) payload.name = updatedData.name
            if (updatedData.steamId) payload.steam_id = updatedData.steamId
            if (updatedData.ip) payload.ip = updatedData.ip
            if (updatedData.banType) payload.ban_type = updatedData.banType
            if (updatedData.reason) payload.reason = updatedData.reason
            if (updatedData.duration) payload.duration = updatedData.duration

            await api.put(`/bans/${id}`, payload)
            await fetchBans()
            return true
        } catch (e) {
            console.error(e)
            return false
        }
    }

    const deleteBanRecord = async (id: number | string) => {
        try {
            await api.delete(`/bans/${id}`)
            await fetchBans()
            return true
        } catch (e) {
            console.error(e)
            return false
        }
    }

    return {
        bans,
        publicBans,
        bansTotal,
        bansPage,
        bansPageSize,
        fetchBans,
        fetchPublicBans,
        addBan,
        removeBan,
        updateBan,
        deleteBanRecord
    }
}
