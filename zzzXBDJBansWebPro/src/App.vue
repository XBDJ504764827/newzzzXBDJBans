<template>
  <router-view />
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '@/composables/useAuthStore'

const { checkAuth } = useAuthStore()

onMounted(async () => {
  await checkAuth()
})
</script>

<style>
/* Global Ant Design Overrides if any */
</style>
