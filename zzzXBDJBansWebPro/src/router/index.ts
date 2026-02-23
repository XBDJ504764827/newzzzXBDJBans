import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import LoginView from '../views/LoginView.vue'
import BasicLayout from '../layouts/BasicLayout.vue'

const routes: Array<RouteRecordRaw> = [
    {
        path: '/',
        name: 'login',
        component: LoginView,
    },
    {
        path: '/apply',
        name: 'apply',
        component: () => import('../views/WhitelistApply.vue'),
    },
    {
        path: '/whitelist-status',
        name: 'whitelist-status',
        component: () => import('../views/WhitelistStatus.vue'),
    },
    {
        path: '/bans',
        name: 'public-bans',
        component: () => import('../views/PublicBanList.vue'),
    },
    {
        path: '/admin',
        component: BasicLayout,
        meta: { requiresAuth: true },
        children: [
            {
                path: '',
                redirect: '/admin/community'
            },
            {
                path: 'community',
                name: 'community',
                component: () => import('../views/admin/CommunityManagement.vue'),
                meta: { title: '社区管理', icon: 'ClusterOutlined' }
            },
            {
                path: 'bans',
                name: 'bans',
                component: () => import('../views/admin/BanList.vue'),
                meta: { title: '封禁管理', icon: 'StopOutlined' }
            },
            {
                path: 'admins',
                name: 'admins',
                component: () => import('../views/admin/AdminList.vue'),
                meta: { title: '管理员列表', icon: 'TeamOutlined' }
            },
            {
                path: 'logs',
                name: 'logs',
                component: () => import('../views/admin/AuditLog.vue'),
                meta: { title: '操作日志', icon: 'FileSearchOutlined', requiresSuperAdmin: true }
            },
            {
                path: 'whitelist',
                name: 'whitelist',
                component: () => import('../views/admin/WhitelistManagement.vue'),
                meta: { title: '白名单管理', icon: 'SafetyCertificateOutlined' }
            },
            {
                path: 'verifications',
                name: 'verifications',
                component: () => import('../views/admin/VerificationList.vue'),
                meta: { title: '验证列表', icon: 'CheckCircleOutlined', requiresSuperAdmin: true }
            },
        ]
    },
    {
        path: '/:pathMatch(.*)*',
        redirect: '/'
    }
]

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes,
})

router.beforeEach((to, _from) => {
    const token = localStorage.getItem('token')
    const userStr = localStorage.getItem('user')
    const user = userStr ? JSON.parse(userStr) : null
    const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
    const requiresSuperAdmin = to.matched.some(record => record.meta.requiresSuperAdmin)

    if (requiresAuth && !token) {
        return '/'
    }

    if (requiresSuperAdmin && user && user.role !== 'system_admin') {
        return '/admin/bans'
    }

    if (to.path === '/' && token) {
        return '/admin'
    }

    return true
})

export default router
