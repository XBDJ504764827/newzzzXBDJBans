<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">封禁管理</h2>
        <p style="color: rgba(0,0,0,0.45); font-size: 14px; margin-top: 4px">管理游戏服务器的玩家封禁记录</p>
      </div>
      <div class="right">
        <a-space>
          <a-button @click="refreshBans" :loading="loading">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
          <a-button type="primary" @click="openAddModal">
            <template #icon><PlusOutlined /></template>
            添加封禁
          </a-button>
        </a-space>
      </div>
    </div>

    <a-card :bordered="false">
      <!-- 搜索区域 -->
      <div class="table-toolbar" style="margin-bottom: 16px">
        <div class="left">
          <a-form layout="inline" :model="searchForm">
            <a-form-item>
              <a-radio-group v-model:value="searchForm.status" button-style="solid">
                <a-radio-button value="all">全部</a-radio-button>
                <a-radio-button value="active">封禁中</a-radio-button>
                <a-radio-button value="unbanned">已解封</a-radio-button>
                <a-radio-button value="expired">已过期</a-radio-button>
              </a-radio-group>
            </a-form-item>
            <a-form-item>
              <a-input-search
                v-model:value="searchForm.query"
                placeholder="搜索昵称 / SteamID / IP"
                style="width: 280px"
                allow-clear
              />
            </a-form-item>
          </a-form>
        </div>
      </div>

      <a-table
        :columns="columns"
        :data-source="filteredBans"
        row-key="id"
        :loading="loading"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'player'">
            <div style="display: flex; flex-direction: column">
              <span style="font-weight: 600">{{ record.name }}</span>
              <span class="mono-text" style="font-size: 11px; color: rgba(0,0,0,0.45)">
                {{ record.steam_id_64 || record.steam_id || '-' }}
              </span>
            </div>
          </template>

          <template v-else-if="column.key === 'status'">
            <a-tag :color="getStatusColor(record.status)">
              {{ getStatusText(record.status) }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'banType'">
            <a-tag color="blue">{{ getBanTypeLabel(record.ban_type) }}</a-tag>
          </template>

          <template v-else-if="column.key === 'action'">
            <a-space>
              <a-button v-if="record.status === 'active'" type="link" size="small" @click="openEditModal(record)">编辑</a-button>
              <a-button v-if="record.status !== 'active'" type="link" size="small" @click="openRebanModal(record)">重新封禁</a-button>
              
              <a-dropdown>
                <a-button type="link" size="small">更多 <DownOutlined /></a-button>
                <template #overlay>
                  <a-menu>
                    <a-menu-item v-if="record.status === 'active'" @click="handleLiftBan(record.id)">
                      <UnlockOutlined /> 解除封禁
                    </a-menu-item>
                    <a-menu-item v-if="isSystemAdmin" danger @click="handleHardDelete(record.id)">
                      <DeleteOutlined /> 彻底删除
                    </a-menu-item>
                  </a-menu>
                </template>
              </a-dropdown>
            </a-space>
          </template>
        </template>

        <!-- 可展开行：详细信息 -->
        <template #expandedRowRender="{ record }">
          <a-descriptions bordered size="small" :column="2">
            <a-descriptions-item label="封禁原因" :span="2">
              {{ record.reason || '无原因' }}
            </a-descriptions-item>
            <a-descriptions-item label="IP 地址">{{ record.ip || 'N/A' }}</a-descriptions-item>
            <a-descriptions-item label="来源服务器">{{ getServerName(record.server_id) }}</a-descriptions-item>
            <a-descriptions-item label="执行管理员">{{ record.admin_name || 'System' }}</a-descriptions-item>
            <a-descriptions-item label="时长">{{ record.duration }}</a-descriptions-item>
            <a-descriptions-item label="封禁时间">{{ record.created_at ? new Date(record.created_at).toLocaleString() : '-' }}</a-descriptions-item>
            <a-descriptions-item label="解封/过期时间">
              <span v-if="record.expires_at">{{ new Date(record.expires_at).toLocaleString() }}</span>
              <span v-else>永久</span>
            </a-descriptions-item>
          </a-descriptions>
        </template>
      </a-table>
    </a-card>

    <!-- Ban Modal (simplified implementation here, should be separate component) -->
    <a-modal
      v-model:open="showModal"
      :title="editMode ? '编辑封禁' : '添加封禁'"
      @ok="handleModalOk"
    >
      <a-form layout="vertical" :model="banForm">
        <a-form-item label="玩家昵称" required>
          <a-input v-model:value="banForm.name" />
        </a-form-item>
        <a-form-item label="SteamID (ID2/ID3/ID64)" required>
          <a-input v-model:value="banForm.steamId" />
        </a-form-item>
        <a-form-item label="IP 地址">
          <a-input v-model:value="banForm.ip" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="封禁类型">
              <a-select v-model:value="banForm.banType">
                <a-select-option value="account">账号封禁</a-select-option>
                <a-select-option value="ip">IP封禁</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="时长 (如 7d, 2h, 0 为永久)">
              <a-input v-model:value="banForm.duration" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="封禁原因">
          <a-textarea v-model:value="banForm.reason" :rows="3" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import type { TablePaginationConfig } from 'ant-design-vue'
import { useBanStore } from '@/composables/useBanStore'
import { useAuthStore } from '@/composables/useAuthStore'
import { useCommunityStore } from '@/composables/useCommunityStore'
import { 
  ReloadOutlined, 
  PlusOutlined, 
  DownOutlined, 
  UnlockOutlined, 
  DeleteOutlined 
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const { bans, bansTotal, bansPage, bansPageSize, addBan, removeBan, updateBan, fetchBans, deleteBanRecord } = useBanStore()
const { currentUser, isSystemAdmin } = useAuthStore()
const { serverGroups, fetchServerGroups } = useCommunityStore()

const loading = ref(false)
const showModal = ref(false)
const editMode = ref(false)
const currentBanId = ref<any>(null)

const searchForm = reactive({
  status: 'all',
  query: ''
})

const banForm = reactive({
  name: '',
  steamId: '',
  ip: '',
  banType: 'account',
  duration: '0',
  reason: ''
})

const columns = [
  { title: 'ID', dataIndex: 'id', key: 'id', width: 80 },
  { title: '玩家信息', key: 'player' },
  { title: '状态', key: 'status', width: 100 },
  { title: '类型', key: 'banType', width: 100 },
  { title: '操作', key: 'action', align: 'right' as const, width: 200 },
]

const pagination = computed(() => ({
  current: bansPage.value,
  pageSize: bansPageSize.value,
  total: bansTotal.value,
  showSizeChanger: true,
  showTotal: (total: number) => `共 ${total} 条`,
}))

onMounted(async () => {
    loading.value = true
    await Promise.all([fetchBans(), fetchServerGroups()])
    loading.value = false
})

const filteredBans = computed(() => {
  let result = bans.value
  if (searchForm.status !== 'all') {
    result = result.filter((b: any) => b.status === searchForm.status)
  }
  if (searchForm.query) {
    const q = searchForm.query.toLowerCase()
    result = result.filter((b: any) =>
      b.name.toLowerCase().includes(q) ||
      (b.steam_id && b.steam_id.toLowerCase().includes(q)) ||
      (b.steam_id_64 && b.steam_id_64.includes(q)) ||
      (b.ip && b.ip.includes(q))
    )
  }
  return result
})

const handleTableChange = async (pager: TablePaginationConfig) => {
  loading.value = true
  try {
    await fetchBans(pager.current || 1, pager.pageSize || 15)
  } finally {
    loading.value = false
  }
}

const refreshBans = async () => {
  loading.value = true
  try {
    await fetchBans()
  } finally {
    loading.value = false
  }
}

const getServerName = (serverId: any) => {
    if (!serverId) return '网页端 / 全局'
    for (const group of serverGroups.value) {
        const server = group.servers.find((s: any) => s.id === serverId)
        if (server) return server.name
    }
    return 'Unknown'
}

const getStatusColor = (status: string) => {
    switch (status) {
        case 'active': return 'error'
        case 'unbanned': return 'success'
        case 'expired': return 'default'
        default: return 'default'
    }
}

const getStatusText = (status: string) => {
    switch (status) {
        case 'active': return '封禁中'
        case 'unbanned': return '已解封'
        case 'expired': return '已过期'
        default: return status
    }
}

const getBanTypeLabel = (type: string) => {
    const map: any = { 'account': '账号', 'ip': 'IP' }
    return map[type] || type
}

const openAddModal = () => {
  editMode.value = false
  currentBanId.value = null
  Object.assign(banForm, { name: '', steamId: '', ip: '', banType: 'account', duration: '0', reason: '' })
  showModal.value = true
}

const openEditModal = (ban: any) => {
  editMode.value = true
  currentBanId.value = ban.id
  Object.assign(banForm, { 
    name: ban.name, 
    steamId: ban.steam_id || ban.steam_id_64, 
    ip: ban.ip || '', 
    banType: ban.ban_type, 
    duration: ban.duration, 
    reason: ban.reason 
  })
  showModal.value = true
}

const openRebanModal = (ban: any) => {
  editMode.value = false
  currentBanId.value = null
  Object.assign(banForm, { 
    name: ban.name, 
    steamId: ban.steam_id || ban.steam_id_64, 
    ip: ban.ip || '', 
    banType: ban.ban_type, 
    duration: '7d', 
    reason: ban.reason 
  })
  showModal.value = true
}

const handleModalOk = async () => {
  if (!banForm.name || !banForm.steamId) return message.warning('请填写必填项')
  try {
    let res
    if (editMode.value) {
      res = await updateBan(currentBanId.value, banForm)
    } else {
      const payload = { ...banForm, adminName: currentUser.value?.username || 'System' }
      res = await addBan(payload)
    }
    if (res === true || (res && res.success)) {
      message.success('操作成功')
      showModal.value = false
    } else {
      message.error('操作失败')
    }
  } catch (e) {
    message.error('系统错误')
  }
}

const handleLiftBan = async (id: any) => {
  const success = await removeBan(id)
  if (success) message.success('封禁已解除')
  else message.error('解除失败')
}

const handleHardDelete = async (id: any) => {
  const success = await deleteBanRecord(id)
  if (success) message.success('记录已彻底删除')
  else message.error('删除失败')
}
</script>
