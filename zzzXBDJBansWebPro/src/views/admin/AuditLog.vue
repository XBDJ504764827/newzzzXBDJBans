<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">操作日志</h2>
        <p style="color: rgba(0,0,0,0.45); font-size: 14px; margin-top: 4px">查看系统管理员的所有操作记录</p>
      </div>
      <div class="right">
        <a-button @click="fetchLogs" :loading="loading">
          <template #icon><ReloadOutlined /></template>
          刷新
        </a-button>
      </div>
    </div>

    <a-card :bordered="false">
      <a-empty v-if="!loading && logs.length === 0" description="暂无操作记录" />
      
      <a-table
        v-else
        :columns="columns"
        :data-source="logs"
        :loading="loading"
        row-key="id"
        :pagination="{ pageSize: 20, showSizeChanger: true }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'time'">
            <span class="mono-text" style="font-size: 13px">
              {{ new Date(record.time).toLocaleString() }}
            </span>
          </template>

          <template v-else-if="column.key === 'admin'">
            <a-tag>{{ record.admin }}</a-tag>
          </template>

          <template v-else-if="column.key === 'action'">
            <span :style="{ color: getActionColor(record.action), fontWeight: 600 }">
              {{ record.action }}
            </span>
          </template>

          <template v-else-if="column.key === 'details'">
            <span style="color: rgba(0,0,0,0.65)">{{ record.details || '-' }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useLogStore } from '@/composables/useLogStore'
import { ReloadOutlined } from '@ant-design/icons-vue'

const { logs, fetchLogs } = useLogStore()
const loading = ref(false)

const columns = [
  { title: '时间', key: 'time', width: 180 },
  { title: '操作人', key: 'admin', width: 120 },
  { title: '动作', key: 'action', width: 150 },
  { title: '目标对象', dataIndex: 'target', key: 'target', width: 200 },
  { title: '详细信息', key: 'details' },
]

onMounted(async () => {
    loading.value = true
    await fetchLogs()
    loading.value = false
})

const getActionColor = (action: string) => {
    if (action.includes('删除') || action.includes('解封') || action.includes('Ban')) return '#ff4d4f' // error
    if (action.includes('新增') || action.includes('创建')) return '#52c41a' // success
    if (action.includes('修改') || action.includes('编辑')) return '#1890ff' // processing
    return 'rgba(0,0,0,0.65)'
}
</script>
