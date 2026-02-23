<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">进服验证列表</h2>
        <p style="color: rgba(0,0,0,0.45); font-size: 14px; margin-top: 4px">查看所有玩家进服时的系统检测记录</p>
      </div>
      <div class="right">
        <a-button @click="fetchVerifications" :loading="loading">
          <template #icon><ReloadOutlined /></template>
          刷新
        </a-button>
      </div>
    </div>

    <a-card :bordered="false">
      <a-table
        :columns="columns"
        :data-source="verifications"
        :loading="loading"
        row-key="steam_id"
        :pagination="{ pageSize: 15, showSizeChanger: true }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'steam_id'">
            <span class="mono-text" style="color: #1890ff">{{ record.steam_id }}</span>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="getStatusColor(record.status)">
              {{ record.status.toUpperCase() }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'reason'">
            <span style="color: rgba(0,0,0,0.65)">{{ record.reason || '-' }}</span>
          </template>

          <template v-else-if="column.key === 'stats'">
            <a-space direction="vertical" size="small">
              <span v-if="record.steam_level !== null">Steam等级: {{ record.steam_level }}</span>
              <span v-if="record.playtime_minutes !== null">GOKZ时长: {{ (record.playtime_minutes / 60).toFixed(1) }}h</span>
              <span v-if="record.steam_level === null && record.playtime_minutes === null">-</span>
            </a-space>
          </template>

          <template v-else-if="column.key === 'time'">
            <span class="mono-text" style="font-size: 12px; color: rgba(0,0,0,0.45)">
              {{ new Date(record.updated_at || record.created_at).toLocaleString() }}
            </span>
          </template>

          <template v-else-if="column.key === 'action'">
            <a-popconfirm title="确定要删除这条验证记录吗？" @confirm="handleDelete(record.steam_id)">
              <a-button type="link" size="small" danger icon-only><DeleteOutlined /></a-button>
            </a-popconfirm>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/utils/api'
import { ReloadOutlined, DeleteOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const verifications = ref<any[]>([])
const loading = ref(false)

const columns = [
  { title: 'Steam ID', key: 'steam_id' },
  { title: '状态', key: 'status', width: 120 },
  { title: '原因/备注', key: 'reason' },
  { title: '系统检测', key: 'stats' },
  { title: '更新时间', key: 'time', width: 180 },
  { title: '操作', key: 'action', align: 'right' as const, width: 80 },
]

const fetchVerifications = async () => {
  loading.value = true
  try {
    const res = await api.get('/verifications')
    verifications.value = res.data
  } catch (err) {
    console.error(err)
    message.error('获取列表失败')
  } finally {
    loading.value = false
  }
}

const handleDelete = async (steam_id: string) => {
  try {
    const res = await api.delete(`/verifications/${steam_id}`)
    if (res.status === 200 || res.status === 204) {
      message.success('记录已删除')
      fetchVerifications()
    }
  } catch (err) {
    console.error(err)
    message.error('删除失败')
  }
}

const getStatusColor = (status: string) => {
    switch(status) {
        case 'allowed': return 'success';
        case 'denied': return 'error';
        default: return 'warning';
    }
}

onMounted(fetchVerifications)
</script>
