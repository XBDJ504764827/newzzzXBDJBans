<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">进服申请管理 (白名单)</h2>
      </div>
      <div class="right">
        <a-space>
          <a-button @click="fetchWhitelist" :loading="loading">
            <template #icon><ReloadOutlined /></template>
            刷新
          </a-button>
          <a-button type="primary" @click="openAddModal">
            <template #icon><PlusOutlined /></template>
            添加玩家
          </a-button>
        </a-space>
      </div>
    </div>

    <a-card :bordered="false" :bodyStyle="{ padding: 0 }">
      <a-tabs v-model:activeKey="activeTab" style="margin: 0 24px">
        <a-tab-pane key="approved" :tab="`已通过 (${approvedPagination.total})`" />
        <a-tab-pane key="pending">
          <template #tab>
            待审核
            <a-badge v-if="pendingPagination.total > 0" :count="pendingPagination.total" :offset="[10, -5]" />
          </template>
        </a-tab-pane>
        <a-tab-pane key="rejected" :tab="`已拒绝 (${rejectedPagination.total})`" />
      </a-tabs>

      <a-table
        :columns="columns"
        :data-source="currentList"
        :loading="loading"
        row-key="id"
        :pagination="currentPagination"
        @change="handleTableChange"
        :customRow="customRow"
        style="padding: 0 24px 24px"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'player'">
            <a-space direction="vertical" size="small">
              <span style="font-weight: 600">{{ record.name }}</span>
              <a-tag v-if="banCache[record.steam_id_64 || record.steam_id]" color="error">Global 封禁记录</a-tag>
            </a-space>
          </template>

          <template v-else-if="column.key === 'steamIds'">
            <div class="mono-text" style="font-size: 12px; display: flex; flex-direction: column; gap: 4px">
              <div v-if="record.steam_id"><span style="color: rgba(0,0,0,0.45)">ID2:</span> {{ record.steam_id }}</div>
              <div v-if="record.steam_id_3"><span style="color: rgba(0,0,0,0.45)">ID3:</span> {{ record.steam_id_3 }}</div>
              <div v-if="record.steam_id_64"><span style="color: rgba(0,0,0,0.45)">ID64:</span> {{ record.steam_id_64 }}</div>
            </div>
          </template>

          <template v-else-if="column.key === 'time'">
            <span class="mono-text" style="font-size: 12px; color: rgba(0,0,0,0.45)">
              {{ new Date(record.created_at).toLocaleString() }}
            </span>
          </template>

          <template v-else-if="column.key === 'handler'">
            {{ record.admin_name || '-' }}
          </template>

          <template v-else-if="column.key === 'reason'">
            <span style="color: #ff4d4f">{{ record.reject_reason || '-' }}</span>
          </template>

          <template v-else-if="column.key === 'action'">
            <a-space>
              <template v-if="activeTab === 'pending'">
                <a-button type="link" size="small" @click="handleApprove(record.id)">通过</a-button>
                <a-button type="link" size="small" danger @click="handleReject(record.id)">拒绝</a-button>
              </template>
              <template v-if="activeTab === 'approved'">
                <a-popconfirm title="确定要删除吗？" @confirm="handleDelete(record.id)">
                  <a-button type="link" size="small" danger>删除</a-button>
                </a-popconfirm>
              </template>
              <template v-if="activeTab === 'rejected'">
                <a-button type="link" size="small" @click="handleApprove(record.id)">恢复通过</a-button>
              </template>
            </a-space>
          </template>
        </template>

        <!-- 封禁检测详情展示 -->
        <template #expandedRowRender="{ record }">
          <div v-if="banCache[record.steam_id_64 || record.steam_id]" style="padding: 12px 0">
            <h4 style="color: #ff4d4f; font-weight: 600; margin-bottom: 16px; display: flex; align-items: center; gap: 8px">
              <GlobalOutlined /> GOKZ 全局封禁记录库
            </h4>
            <div style="display: flex; flex-direction: column; gap: 16px">
              <a-card 
                v-for="item in banCache[record.steam_id_64 || record.steam_id]" 
                :key="item.id" 
                size="small" 
                :bordered="true"
                style="border-left: 4px solid #ff4d4f; border-radius: 4px; background: #fffcfc"
              >
                <div style="display: flex; gap: 16px">
                  <!-- 头像展示 -->
                  <div style="flex-shrink: 0">
                    <a-avatar :size="64" shape="square" :src="`https://avatars.steamstatic.com/${item.avatar_hash}_full.jpg`" v-if="item.avatar_hash">
                      {{ item.player_name?.charAt(0) }}
                    </a-avatar>
                    <a-avatar :size="64" shape="square" v-else>
                      {{ item.player_name?.charAt(0) }}
                    </a-avatar>
                  </div>

                  <!-- 核心内容 -->
                  <div style="flex: 1">
                    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px">
                      <div>
                        <span style="font-size: 16px; font-weight: 600; margin-right: 8px">{{ item.player_name }}</span>
                        <a-tag color="error">{{ item.ban_type }}</a-tag>
                        <a-tag :color="item.expires_on ? (new Date(item.expires_on) > new Date() ? 'error' : 'default') : 'error'">
                          {{ item.expires_on ? (new Date(item.expires_on) > new Date() ? '生效中' : '已过期') : '永久封禁' }}
                        </a-tag>
                      </div>
                      <span class="mono-text" style="color: rgba(0,0,0,0.45); font-size: 12px">#{{ item.id }}</span>
                    </div>

                    <a-descriptions size="small" :column="3" style="margin-bottom: 12px">
                      <a-descriptions-item label="服务器">{{ item.server_name }} (ID: {{ item.server_id }})</a-descriptions-item>
                      <a-descriptions-item label="封禁时间">{{ new Date(item.created_on).toLocaleString() }}</a-descriptions-item>
                      <a-descriptions-item label="到期时间">{{ item.expires_on ? new Date(item.expires_on).toLocaleString() : '永久' }}</a-descriptions-item>
                    </a-descriptions>

                    <!-- 管理员备注 -->
                    <div v-if="item.notes" style="background: rgba(0,0,0,0.02); padding: 8px; border-radius: 4px; margin-bottom: 12px; border: 1px dashed rgba(0,0,0,0.1)">
                      <div style="font-size: 12px; color: rgba(0,0,0,0.45); margin-bottom: 4px">管理员备注 (Notes):</div>
                      <div style="font-size: 13px; color: rgba(0,0,0,0.85)">{{ item.notes }}</div>
                    </div>

                    <!-- 详细检测报告 stats -->
                    <div v-if="item.stats" style="background: #1e1e1e; color: #d4d4d4; padding: 12px; border-radius: 4px; font-family: 'JetBrains Mono', monospace; font-size: 12px; overflow-x: auto">
                      <div style="color: #6a9955; margin-bottom: 4px">// 系统自动检测报告 (System Stats)</div>
                      <div style="white-space: pre-wrap">{{ item.stats }}</div>
                    </div>
                  </div>
                </div>
              </a-card>
            </div>
          </div>
          <div v-else style="color: rgba(0,0,0,0.45); text-align: center; padding: 24px">无全局封禁记录</div>
        </template>
      </a-table>
    </a-card>

    <!-- Add Modal -->
    <a-modal v-model:open="showAddModal" title="添加玩家到白名单" @ok="handleAdd">
      <a-form layout="vertical">
        <a-form-item label="Steam ID" required help="支持 SteamID64, ID2, ID3 等">
          <a-input-search
            v-model:value="addForm.steam_id"
            placeholder="例如: 76561198..."
            enter-button="获取信息"
            @search="handleLookup"
            :loading="lookupLoading"
          />
        </a-form-item>
        <a-form-item label="玩家昵称">
          <a-input v-model:value="addForm.name" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Reject Modal -->
    <a-modal v-model:open="showRejectModal" title="拒绝申请" @ok="confirmReject">
      <a-form layout="vertical">
        <a-form-item label="拒绝理由" required>
          <a-textarea v-model:value="rejectReason" placeholder="请输入拒绝理由..." :rows="3" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Context Menu -->
    <div 
      v-if="showContextMenu" 
      class="context-menu"
      :style="{ top: menuPos.y + 'px', left: menuPos.x + 'px' }"
    >
      <div class="menu-header">{{ menuRecord?.name }}</div>
      <div class="menu-item" @click="handleCopySteamID">
        <CopyOutlined /> 复制 SteamID
      </div>
      <div class="menu-item" @click="handleViewSteamProfile">
        <UserOutlined /> 查看 Steam 主页
      </div>
      <div class="menu-item" @click="handleViewGokzProfile">
        <GlobalOutlined /> 查看 GOKZ.TOP 主页
      </div>
      <div class="menu-item" @click="handleViewKzgoProfile">
        <GlobalOutlined /> 查看 KZGO.EU 主页
      </div>
      <a-divider style="margin: 4px 0" />
      <template v-if="activeTab === 'pending'">
        <div class="menu-item" @click="handleApprove(menuRecord.id)">
          <CheckCircleOutlined /> 快速通过
        </div>
        <div class="menu-item danger" @click="handleReject(menuRecord.id)">
          <CloseCircleOutlined /> 快速拒绝
        </div>
      </template>
      <template v-if="activeTab === 'approved'">
        <div class="menu-item danger" @click="handleDelete(menuRecord.id)">
          <DeleteOutlined /> 删除白名单
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted, watch } from 'vue'
import type { TablePaginationConfig } from 'ant-design-vue'
import { useRouter, useRoute } from 'vue-router'
import api from '@/utils/api'
import { 
  ReloadOutlined, 
  PlusOutlined, 
  CopyOutlined, 
  UserOutlined, 
  GlobalOutlined,
  CheckCircleOutlined, 
  CloseCircleOutlined,
  DeleteOutlined 
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const activeTab = ref<string>((route.query.tab as string) || 'approved')

const whitelist = ref<any[]>([])
const pendingList = ref<any[]>([])
const rejectedList = ref<any[]>([])
const approvedPagination = reactive({ current: 1, pageSize: 15, total: 0 })
const pendingPagination = reactive({ current: 1, pageSize: 15, total: 0 })
const rejectedPagination = reactive({ current: 1, pageSize: 15, total: 0 })

const banCache = ref<any>({})
const lookupLoading = ref(false)
const showAddModal = ref(false)
const showRejectModal = ref(false)
const rejectReason = ref('')
const rejectTargetId = ref<any>(null)

const addForm = reactive({
  steam_id: '',
  name: ''
})

// Context Menu State
const showContextMenu = ref(false)
const menuPos = ref({ x: 0, y: 0 })
const menuRecord = ref<any>(null)

const customRow = (record: any) => {
  return {
    onContextmenu: (event: MouseEvent) => {
      event.preventDefault()
      menuRecord.value = record
      menuPos.value = { x: event.clientX, y: event.clientY }
      showContextMenu.value = true
    }
  }
}

// Global click listener to close context menu
const closeMenu = () => {
  showContextMenu.value = false
}

watch(showContextMenu, (val) => {
  if (val) {
    window.addEventListener('click', closeMenu)
  } else {
    window.removeEventListener('click', closeMenu)
  }
})

const columns = computed(() => {
  const base: any[] = [
    { title: '玩家', key: 'player', width: 200 },
    { title: 'Steam IDs', key: 'steamIds' },
    { title: '申请时间', key: 'time', width: 180 },
  ];
  if (activeTab.value === 'approved' || activeTab.value === 'rejected') {
    base.push({ title: '执行管理', key: 'handler', width: 120 });
  }
  if (activeTab.value === 'rejected') base.push({ title: '拒绝理由', key: 'reason' });
  base.push({ title: '操作', key: 'action', align: 'right', width: 150 });
  return base;
})

const currentList = computed(() => {
  if (activeTab.value === 'approved') return whitelist.value
  if (activeTab.value === 'pending') return pendingList.value
  return rejectedList.value
})

const currentPagination = computed(() => {
  const source = activeTab.value === 'approved'
    ? approvedPagination
    : activeTab.value === 'pending'
      ? pendingPagination
      : rejectedPagination

  return {
    current: source.current,
    pageSize: source.pageSize,
    total: source.total,
    showSizeChanger: true,
    showTotal: (total: number) => `共 ${total} 条`,
  }
})

watch(activeTab, (newTab) => {
    router.replace({ query: { ...route.query, tab: newTab } })
    fetchWhitelist()
})

const fetchApprovedList = async () => {
  const res = await api.get('/whitelist', {
    params: { page: approvedPagination.current, page_size: approvedPagination.pageSize }
  })
  whitelist.value = res.data.items
  approvedPagination.current = res.data.page
  approvedPagination.pageSize = res.data.page_size
  approvedPagination.total = res.data.total
}

const fetchPendingList = async () => {
  const res = await api.get('/whitelist/pending', {
    params: { page: pendingPagination.current, page_size: pendingPagination.pageSize }
  })
  pendingList.value = res.data.items
  pendingPagination.current = res.data.page
  pendingPagination.pageSize = res.data.page_size
  pendingPagination.total = res.data.total
}

const fetchRejectedList = async () => {
  const res = await api.get('/whitelist/rejected', {
    params: { page: rejectedPagination.current, page_size: rejectedPagination.pageSize }
  })
  rejectedList.value = res.data.items
  rejectedPagination.current = res.data.page
  rejectedPagination.pageSize = res.data.page_size
  rejectedPagination.total = res.data.total
}

const fetchWhitelist = async () => {
  loading.value = true
  try {
    await Promise.all([fetchApprovedList(), fetchPendingList(), fetchRejectedList()])

    // 异步检查封禁
    checkGlobalBans(currentList.value)
  } catch (err) {
    console.error(err)
    message.error('获取列表失败')
  } finally {
    loading.value = false
  }
}

const checkGlobalBans = async (list: any[]) => {
    const ids = list.map(i => i.steam_id_64 || i.steam_id).filter(id => id && banCache.value[id] === undefined)
    if (ids.length === 0) return
    try {
        const res = await api.post('/check_global_ban/bulk', { steam_ids: ids })
        if (res.data) {
            Object.entries(res.data).forEach(([id, data]: any) => {
                if (data && (Array.isArray(data) ? data.length > 0 : (data.data && data.data.length > 0))) {
                    banCache.value[id] = Array.isArray(data) ? data : data.data
                }
            })
        }
    } catch (e) {
        console.error('Check bans failed', e)
    }
}

const handleTableChange = async (pager: TablePaginationConfig) => {
  const current = pager.current || 1
  const pageSize = pager.pageSize || 15

  if (activeTab.value === 'approved') {
    approvedPagination.current = current
    approvedPagination.pageSize = pageSize
  } else if (activeTab.value === 'pending') {
    pendingPagination.current = current
    pendingPagination.pageSize = pageSize
  } else {
    rejectedPagination.current = current
    rejectedPagination.pageSize = pageSize
  }

  await fetchWhitelist()
}

const handleLookup = async () => {
    if (!addForm.steam_id) return
    lookupLoading.value = true
    try {
        const res = await api.get('/whitelist/player-info', { params: { steam_id: addForm.steam_id } })
        if (res.data) {
            addForm.name = res.data.personaname
            addForm.steam_id = res.data.steamid
        }
    } catch (err) {
        message.error('玩家信息获取失败')
    } finally {
        lookupLoading.value = false
    }
}

const handleAdd = async () => {
    if (!addForm.steam_id) return
    try {
        const res = await api.post('/whitelist', addForm)
        if (res.status === 201) {
            message.success('已添加')
            showAddModal.value = false
            if (activeTab.value !== 'approved') {
              activeTab.value = 'approved'
            }
            approvedPagination.current = 1
            await fetchWhitelist()
        }
    } catch (err: any) {
        message.error('添加失败: ' + (err.response?.data?.error || ''))
    }
}

const handleApprove = async (id: any) => {
  try {
    await api.put(`/whitelist/${id}/approve`)
    message.success('已通过')
    if (activeTab.value === 'pending' && pendingList.value.length === 1 && pendingPagination.current > 1) {
      pendingPagination.current -= 1
    }
    await fetchWhitelist()
  } catch (err) {
    message.error('操作失败')
  }
}

const handleReject = (id: any) => {
  rejectTargetId.value = id
  rejectReason.value = ''
  showRejectModal.value = true
}

const confirmReject = async () => {
  if (!rejectReason.value) return message.warning('请填写理由')
  try {
    await api.put(`/whitelist/${rejectTargetId.value}/reject`, { reason: rejectReason.value })
    message.success('已拒绝')
    showRejectModal.value = false
    if (activeTab.value === 'pending' && pendingList.value.length === 1 && pendingPagination.current > 1) {
      pendingPagination.current -= 1
    }
    await fetchWhitelist()
  } catch (err) {
    message.error('操作失败')
  }
}

const handleDelete = async (id: any) => {
  try {
    await api.delete(`/whitelist/${id}`)
    message.success('已删除')
    if (activeTab.value === 'approved' && whitelist.value.length === 1 && approvedPagination.current > 1) {
      approvedPagination.current -= 1
    } else if (activeTab.value === 'pending' && pendingList.value.length === 1 && pendingPagination.current > 1) {
      pendingPagination.current -= 1
    } else if (activeTab.value === 'rejected' && rejectedList.value.length === 1 && rejectedPagination.current > 1) {
      rejectedPagination.current -= 1
    }
    await fetchWhitelist()
  } catch (err) {
    message.error('删除失败')
  }
}

const openAddModal = () => {
  Object.assign(addForm, { steam_id: '', name: '' })
  showAddModal.value = true
}

const handleCopySteamID = () => {
  const id = menuRecord.value?.steam_id_64 || menuRecord.value?.steam_id
  if (id) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(id).then(() => {
        message.success('已复制: ' + id)
      }).catch(() => {
        message.error('复制失败')
      })
    } else {
      // Fallback for older browsers
      const textArea = document.createElement("textarea")
      textArea.value = id
      document.body.appendChild(textArea)
      textArea.select()
      document.execCommand("copy")
      document.body.removeChild(textArea)
      message.success('已复制: ' + id)
    }
  }
}

const handleViewSteamProfile = () => {
  const id64 = menuRecord.value?.steam_id_64
  if (id64) {
    window.open(`https://steamcommunity.com/profiles/${id64}`, '_blank')
  } else {
    message.warning('无法确认 SteamID64')
  }
}

const handleViewGokzProfile = () => {
  const id = menuRecord.value?.steam_id_64 || menuRecord.value?.steam_id
  if (id) {
    window.open(`https://gokz.top/profile/${id}`, '_blank')
  }
}

const handleViewKzgoProfile = () => {
  const id = menuRecord.value?.steam_id_64 || menuRecord.value?.steam_id
  if (id) {
    window.open(`https://kzgo.eu/players/${id}`, '_blank')
  }
}

onMounted(fetchWhitelist)

onUnmounted(() => {
  window.removeEventListener('click', closeMenu)
})
</script>

<style scoped>
:deep(.ant-tabs-nav) {
  margin-bottom: 0;
}

.context-menu {
  position: fixed;
  z-index: 1000;
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 6px 16px 0 rgba(0, 0, 0, 0.08), 0 3px 6px -4px rgba(0, 0, 0, 0.12), 0 9px 28px 8px rgba(0, 0, 0, 0.05);
  padding: 4px 0;
  min-width: 160px;
  border: 1px solid rgba(0, 0, 0, 0.06);
}

.menu-header {
  padding: 8px 12px;
  font-weight: 600;
  color: rgba(0,0,0,0.85);
  font-size: 13px;
  border-bottom: 1px solid rgba(0,0,0,0.06);
  margin-bottom: 4px;
  background: #fafafa;
  border-radius: 8px 8px 0 0;
}

.menu-item {
  padding: 8px 12px;
  font-size: 14px;
  color: rgba(0,0,0,0.65);
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 8px;
}

.menu-item:hover {
  background-color: #f5f5f5;
  color: #1890ff;
}

.menu-item.danger {
  color: #ff4d4f;
}

.menu-item.danger:hover {
  background-color: #fff1f0;
  color: #ff4d4f;
}
</style>
