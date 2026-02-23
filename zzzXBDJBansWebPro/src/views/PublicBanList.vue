<template>
  <div class="page-container">
    <div style="margin-bottom: 24px">
      <h2 style="font-size: 24px; font-weight: 600; margin-bottom: 8px">封禁公示</h2>
      <p style="color: rgba(0,0,0,0.45)">服务器违规与封禁记录公示</p>
    </div>

    <a-card :bordered="false">
      <!-- 搜索和过滤区域 -->
      <div class="table-toolbar">
        <div class="left">
          <a-form layout="inline" :model="searchForm">
            <a-form-item>
              <a-radio-group v-model:value="searchForm.tab" button-style="solid">
                <a-radio-button value="all">全部</a-radio-button>
                <a-radio-button value="active">生效中</a-radio-button>
              </a-radio-group>
            </a-form-item>
            <a-form-item>
              <a-input-search
                v-model:value="searchForm.query"
                placeholder="搜索玩家昵称 / SteamID..."
                style="width: 300px"
                @search="handleSearch"
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

      <!-- 表格区域 -->
      <a-table
        :columns="columns"
        :data-source="filteredList"
        :loading="loading"
        :pagination="{ pageSize: 15, showSizeChanger: true }"
        row-key="id"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="record.status === 'active' ? 'error' : 'default'">
              {{ record.status === 'active' ? '生效中' : '已过期/解封' }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'player'">
            <div style="display: flex; flex-direction: column">
              <div style="font-weight: 600">
                {{ record.name }}
                <a 
                  v-if="record.steam_id_64"
                  :href="`https://steamcommunity.com/profiles/${record.steam_id_64}`" 
                  target="_blank"
                  style="margin-left: 8px; font-size: 12px"
                >
                  <LinkOutlined /> Steam
                </a>
              </div>
              <div class="mono-text" style="font-size: 12px; color: rgba(0,0,0,0.45)">
                <span v-if="record.steam_id_64">ID64: {{ record.steam_id_64 }}</span><br />
                <span v-if="record.steam_id">ID2: {{ record.steam_id }}</span>
              </div>
            </div>
          </template>

          <template v-else-if="column.key === 'reason'">
            <a-tooltip :title="record.reason" v-if="record.reason">
              <div style="max-width: 200px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                {{ record.reason }}
              </div>
            </a-tooltip>
            <span v-else color="rgba(0,0,0,0.25)">无原因</span>
          </template>

          <template v-else-if="column.key === 'duration'">
            <div style="display: flex; flex-direction: column">
              <span>{{ formatDuration(record.duration) }}</span>
              <span v-if="record.expires_at" style="font-size: 11px; color: rgba(0,0,0,0.45)">
                至 {{ formatDate(record.expires_at) }}
              </span>
              <span v-else style="font-size: 11px; color: #ff4d4f">永久</span>
            </div>
          </template>

          <template v-else-if="column.key === 'time'">
            <span class="mono-text">{{ formatDate(record.created_at) }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useBanStore } from '@/composables/useBanStore'
import { ReloadOutlined, LinkOutlined } from '@ant-design/icons-vue'

const { publicBans, fetchPublicBans } = useBanStore()
const loading = ref(true)

const searchForm = reactive({
  tab: 'active',
  query: ''
})

const columns = [
  { title: '状态', key: 'status', width: 100 },
  { title: '玩家信息', key: 'player' },
  { title: '封禁原因', key: 'reason' },
  { title: '时长 / 到期', key: 'duration' },
  { title: '执行时间', key: 'time', align: 'right' as const },
]

const fetchList = async () => {
  loading.value = true
  try {
    await fetchPublicBans()
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  // Computed property handles search
}

const filteredList = computed(() => {
  let result = publicBans.value
  
  if (searchForm.tab === 'active') {
    result = result.filter((item: any) => item.status === 'active')
  }

  if (searchForm.query) {
    const q = searchForm.query.toLowerCase()
    result = result.filter((item: any) => 
      item.name.toLowerCase().includes(q) || 
      (item.steam_id && item.steam_id.toLowerCase().includes(q)) ||
      (item.steam_id_64 && item.steam_id_64.includes(q))
    )
  }

  return result
})

const formatDate = (dateString: string) => {
  if (!dateString) return 'N/A'
  return new Date(dateString).toLocaleString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
  })
}

const formatDuration = (durationStr: any) => {
  if (!durationStr || durationStr === '0' || durationStr === '0.0' || durationStr === 'Permanent' || durationStr === 0) return '永久'
  
  const str = String(durationStr).toLowerCase()
  if (str.endsWith('d')) return `${parseFloat(str)} 天`
  if (str.endsWith('h')) return `${parseFloat(str)} 小时`
  if (str.endsWith('m')) return `${parseFloat(str)} 分钟`
  if (str.endsWith('mo')) return `${parseFloat(str)} 个月`
  if (str.endsWith('y')) return `${parseFloat(str)} 年`

  const minutes = parseInt(durationStr)
  if (isNaN(minutes)) return durationStr
  if (minutes < 60) return `${minutes} 分钟`
  if (minutes < 1440) return `${(minutes / 60).toFixed(1)} 小时`
  return `${(minutes / 1440).toFixed(1)} 天`
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
