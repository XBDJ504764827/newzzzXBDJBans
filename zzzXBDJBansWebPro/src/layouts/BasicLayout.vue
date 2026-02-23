<template>
  <a-layout style="min-height: 100vh">
    <!-- Sider -->
    <a-layout-sider v-model:collapsed="collapsed" collapsible theme="dark">
      <div class="logo">
        <h1 v-if="!collapsed">zzzXBDJBans</h1>
        <h1 v-else>ZB</h1>
      </div>
      <a-menu v-model:selectedKeys="selectedKeys" theme="dark" mode="inline">
        <template v-for="item in menuItems" :key="item.path">
          <a-menu-item v-if="!(item as any).children" :key="item.path" @click="handleMenuClick(item.path)">
            <template #icon>
              <component :is="item.icon" v-if="item.icon" />
            </template>
            <span>{{ item.title }}</span>
          </a-menu-item>
        </template>
      </a-menu>
    </a-layout-sider>

    <a-layout>
      <!-- Header -->
      <a-layout-header style="background: #fff; padding: 0 24px; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 1px 4px rgba(0,21,41,.08); z-index: 10;">
        <div style="display: flex; align-items: center">
          <a-breadcrumb style="margin-left: 16px">
            <a-breadcrumb-item>管理系统</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="user-info">
          <a-dropdown>
            <span class="user-dropdown">
              <a-avatar size="small" :src="userAvatar" />
              <span style="margin-left: 8px">{{ currentUser?.username || 'Admin' }}</span>
            </span>
            <template #overlay>
              <a-menu>
                <a-menu-item @click="handleLogout">
                  <LogoutOutlined />
                  退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>

      <!-- Content -->
      <a-layout-content style="margin: 24px 16px; padding: 0; background: #f5f7fa; min-height: 280px">
        <div style="padding: 0">
           <router-view />
        </div>
      </a-layout-content>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/composables/useAuthStore'
import { 
  LogoutOutlined
} from '@ant-design/icons-vue'

const router = useRouter()
const route = useRoute()
const { currentUser, logout, isSystemAdmin } = useAuthStore()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])

// Sync menu selection with route
watch(() => route.path, (val) => {
  selectedKeys.value = [val]
})

const menuItems = computed(() => {
  const adminRoutes = router.options.routes.find(r => r.path === '/admin')?.children || []
  return adminRoutes
    .filter(r => r.meta?.title && (!r.meta?.requiresSuperAdmin || isSystemAdmin.value))
    .map(r => ({
      path: `/admin/${r.path}`.replace(/\/$/, ''),
      title: r.meta?.title as string,
      icon: r.meta?.icon as string
    }))
})

const currentTitle = computed(() => {
  const match = menuItems.value.find(item => item.path === route.path)
  return match?.title || ''
})

const userAvatar = 'https://gw.alipayobjects.com/zos/antfincdn/XAosXuNZyF/BiazfanxmamNRoxxVxka.png'

const handleMenuClick = (path: string) => {
  router.push(path)
}

const handleLogout = async () => {
  await logout()
  router.push('/')
}
</script>

<style scoped>
.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  overflow: hidden;
}
.logo h1 {
  color: #fff;
  font-size: 18px;
  margin: 0;
  font-weight: 600;
  white-space: nowrap;
}
.user-dropdown {
  cursor: pointer;
  padding: 0 12px;
  transition: all 0.3s;
}
.user-dropdown:hover {
  background: rgba(0, 0, 0, 0.025);
}
</style>
