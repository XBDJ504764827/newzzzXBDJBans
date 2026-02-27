import { ref, computed } from 'vue'
import api from '../utils/api'

// State
const currentUser = ref<any>(null)
const adminList = ref<any[]>([])
const adminsTotal = ref(0)
const adminsPage = ref(1)
const adminsPageSize = ref(15)

export const useAuthStore = () => {

    // Login
    const login = async (username: string, password: string) => {
        try {
            const res = await api.post('/auth/login', { username, password })
            const { token, user } = res.data
            localStorage.setItem('token', token)
            localStorage.setItem('user', JSON.stringify(user)) // Simple cache
            currentUser.value = { ...user, token }
            return { success: true, user }
        } catch (error: any) {
            console.error(error)
            return { success: false, message: error.response?.data?.error || '登录失败' }
        }
    }

    // Restore Session from LocalStorage
    const checkAuth = async () => {
        const token = localStorage.getItem('token')
        const userStr = localStorage.getItem('user')
        if (token && userStr) {
            try {
                currentUser.value = { ...JSON.parse(userStr), token }
                return true
            } catch (e) {
                logout()
                return false
            }
        }
        return false
    }

    const logout = async () => {
        try {
            await api.post('/auth/logout')
        } catch (e) { /* ignore */ }
        currentUser.value = null
        localStorage.removeItem('token')
        localStorage.removeItem('user')
    }

    // Fetch Admins
    const fetchAdmins = async (page = adminsPage.value, pageSize = adminsPageSize.value) => {
        try {
            const res = await api.get('/admins', { params: { page, page_size: pageSize } })
            adminList.value = res.data.items
            adminsTotal.value = res.data.total
            adminsPage.value = res.data.page
            adminsPageSize.value = res.data.page_size
        } catch (e) {
            console.error("Failed to fetch admins", e)
        }
    }

    // New Admin
    const addAdmin = async (adminData: any) => {
        try {
            await api.post('/admins', adminData)
            await fetchAdmins() // Refresh list
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '添加失败' }
        }
    }

    // Update Admin
    const updateAdmin = async (id: number | string, updatedData: any) => {
        try {
            const payload = { ...updatedData }
            if (updatedData.steamId) {
                payload.steam_id = updatedData.steamId
                delete payload.steamId
            }
            if (!payload.password) {
                delete payload.password
            }

            await api.put(`/admins/${id}`, payload)
            await fetchAdmins()

            if (currentUser.value && currentUser.value.id == id) {
                Object.assign(currentUser.value, updatedData)
                localStorage.setItem('user', JSON.stringify(currentUser.value))
            }
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '更新失败' }
        }
    }

    // Delete Admin
    const deleteAdmin = async (id: number | string) => {
        try {
            await api.delete(`/admins/${id}`)
            await fetchAdmins()
            return { success: true }
        } catch (e: any) {
            return { success: false, message: e.response?.data || '删除失败' }
        }
    }

    // Change Password
    const changePassword = async (oldPassword: string, newPassword: string) => {
        try {
            const res = await api.post('/auth/change-password', {
                old_password: oldPassword,
                new_password: newPassword
            })
            return { success: true, message: res.data.message }
        } catch (e: any) {
            return { success: false, message: e.response?.data?.error || '修改失败' }
        }
    }

    const isSystemAdmin = computed(() => {
        return currentUser.value && currentUser.value.role === 'super_admin'
    })

    return {
        currentUser,
        adminList,
        adminsTotal,
        adminsPage,
        adminsPageSize,
        isSystemAdmin,
        login,
        checkAuth,
        logout,
        fetchAdmins,
        addAdmin,
        updateAdmin,
        deleteAdmin,
        changePassword
    }
}
