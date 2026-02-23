<template>
  <div class="page-container">
    <div style="margin-bottom: 24px">
      <h2 style="font-size: 24px; font-weight: 600; margin-bottom: 8px">白名单审核状态</h2>
      <p style="color: rgba(0,0,0,0.45)">查看所有的白名单申请及其审核进度</p>
    </div>

    <a-card :bordered="false">
      <div class="table-toolbar">
        <div class="left">
          <a-form layout="inline" :model="searchForm">
            <a-form-item>
              <a-radio-group v-model:value="searchForm.tab" button-style="solid">
                <a-radio-button value="all">全部 ({{ getCount('all') }})</a-radio-button>
                <a-radio-button value="approved">已通过 ({{ getCount('approved') }})</a-radio-button>
                <a-radio-button value="pending">审核中 ({{ getCount('pending') }})</a-radio-button>
                <a-radio-button value="rejected">已拒绝 ({{ getCount('rejected') }})</a-radio-button>
              </a-radio-group>
            </a-form-item>
            <a-form-item>
              <a-input-search
                v-model:value="searchForm.query"
                placeholder="搜索玩家昵称 / SteamID..."
                style="width: 300px"
                allow-clear
              />
            </a-form-item>
          </a-form>
        </div>
        <div class="right">
          <a-button @click="fetchList" :loading="loading">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
        </div>
      </div>

      <a-table
        :columns="columns"
        :data-source="filteredList"
        :loading="loading"
        :pagination="{ pageSize: 15, showSizeChanger: true }"
        row-key="id"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="getStatusColor(record.status)">
              {{ getStatusText(record.status) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'player'">
            <div style="display: flex; flex-direction: column">
              <div style="font-weight: 600">{{ record.name }}</div>
              <div class="mono-text" style="font-size: 12px; color: rgba(0,0,0,0.45)">
                <span v-if="record.steam_id_64">ID64: {{ record.steam_id_64 }}</span><br />
                <span v-if="record.steam_id">ID2: {{ record.steam_id }}</span>
              </div>
            </div>
          </template>

          <template v-else-if="column.key === 'time'">
            <span class="mono-text">{{ formatDate(record.created_at || record.createTime) }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ReloadOutlined } from '@ant-design/icons-vue'
import api from '@/utils/api'
import { message } from 'ant-design-vue'

const list = ref<any[]>([])
const loading = ref(true)

const searchForm = reactive({
  tab: 'all',
  query: ''
})

const columns = [
  { title: '状态', key: 'status', width: 120 },
  { title: '玩家信息', key: 'player' },
  { title: '申请时间', key: 'time', align: 'right' as const },
]

const fetchList = async () => {
    loading.value = true
    try {
        const response = await api.get('/whitelist/public-list')
        if (Array.isArray(response.data)) {
            list.value = response.data
        }
    } catch (error) {
        console.error('Failed to fetch whitelist:', error)
        message.error('获取列表失败')
    } finally {
        loading.value = false
    }
}

const filteredList = computed(() => {
    let result = list.value
    if (searchForm.tab !== 'all') {
        result = result.filter(item => item.status === searchForm.tab)
    }
    if (searchForm.query) {
        const q = searchForm.query.toLowerCase()
        result = result.filter(item => 
            item.name.toLowerCase().includes(q) || 
            (item.steam_id && item.steam_id.includes(q)) ||
            (item.steam_id_64 && item.steam_id_64.includes(q))
        )
    }
    return result
})

const getCount = (status: string) => {
    if (status === 'all') return list.value.length
    return list.value.filter(item => item.status === status).length
}

const formatDate = (dateString: string) => {
    if (!dateString) return 'N/A'
    return new Date(dateString).toLocaleString('zh-CN')
}

const getStatusText = (status: string) => {
    const map: any = {
        'approved': '已通过',
        'pending': '审核中',
        'rejected': '已拒绝'
    }
    return map[status] || status
}

const getStatusColor = (status: string) => {
    const map: any = {
        'approved': 'success',
        'pending': 'processing',
        'rejected': 'error'
    }
    return map[status] || 'default'
}

onMounted(() => {
    fetchList()
})
</script>

<style scoped>
.table-toolbar {
  display: flex;
  justify-content: space-between;
  margin-bottom: 24px;
}
</style>
