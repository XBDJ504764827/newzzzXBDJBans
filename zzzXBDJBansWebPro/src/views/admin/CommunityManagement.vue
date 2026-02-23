<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">社区组管理</h2>
      </div>
      <div class="right">
        <a-button type="primary" @click="openCreateGroupModal">
          <template #icon><PlusOutlined /></template>
          新建服务器组
        </a-button>
      </div>
    </div>

    <!-- Empty State -->
    <a-empty v-if="!hasCommunity" :description="'您还没有创建任何社区组'" style="margin-top: 100px">
      <a-button type="primary" @click="openCreateGroupModal">开始创建</a-button>
    </a-empty>

    <!-- Content List -->
    <div v-else class="group-list">
      <a-card 
        v-for="group in serverGroups" 
        :key="group.id" 
        :title="group.name"
        style="margin-bottom: 24px"
        :headStyle="{ background: '#fafafa' }"
      >
        <template #extra>
          <a-space>
            <a-button type="link" size="small" @click="openAddServerModal(group.id)">
              <PlusOutlined /> 添加服务器
            </a-button>
            <a-popconfirm title="确定要删除这个服务器组吗？组内所有服务器也将被删除。" @confirm="handleDeleteGroup(group.id)">
              <a-button type="link" size="small" danger>删除组</a-button>
            </a-popconfirm>
          </a-space>
        </template>

        <div v-if="group.servers.length === 0" style="text-align: center; color: rgba(0,0,0,0.45); padding: 40px 0">
          该组下暂无服务器，请点击右上角添加
        </div>
        
        <a-row v-else :gutter="[16, 16]">
          <a-col v-for="server in group.servers" :key="server.id" :xs="24" :sm="12" :md="8" :lg="6">
            <a-card hoverable size="small" :bodyStyle="{ padding: '16px' }">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px">
                <div style="font-weight: 600; font-size: 15px; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap">
                  {{ server.name }}
                  <span style="font-size: 12px; color: rgba(0,0,0,0.45); font-weight: normal; margin-left: 8px; font-family: monospace;">
                    #{{ server.id }}
                  </span>
                </div>
                <a-badge :status="server.status === 'online' ? 'processing' : 'default'" />
              </div>
              
              <div style="font-size: 13px; color: rgba(0,0,0,0.65); margin-bottom: 8px">
                {{ server.ip }}:{{ server.port }}
              </div>
              
              <div style="margin-bottom: 16px; display: flex; flex-direction: column; gap: 4px;">
                <a-tag :color="server.enable_whitelist ? 'purple' : 'default'" style="width: fit-content;">
                  📝 {{ server.enable_whitelist ? '白名单模式: 开启' : '白名单模式: 关闭' }}
                </a-tag>
                <a-tag :color="server.verification_enabled ? 'success' : 'default'" style="width: fit-content;">
                  🛡️ {{ server.verification_enabled ? `验证开启 (需等级≥${server.min_steam_level}, Rating≥${server.min_rating})` : '验证关闭' }}
                </a-tag>
              </div>
              
              <a-divider style="margin: 12px 0" />
              
              <div style="display: flex; gap: 8px">
                <a-button size="small" style="flex: 1" @click="openEditServerModal(group.id, server)">管理</a-button>
                <a-button size="small" type="primary" style="flex: 1" @click="openPlayersModal(server)">玩家</a-button>
                <a-popconfirm title="确定删除？" @confirm="handleDeleteServer(group.id, server.id)">
                  <a-button size="small" danger icon-only><DeleteOutlined /></a-button>
                </a-popconfirm>
              </div>
            </a-card>
          </a-col>
        </a-row>
      </a-card>
    </div>

    <!-- Server Edit/Add Modal -->
    <a-modal 
      v-model:open="showServerModal" 
      :title="currentEditingServer ? '编辑服务器' : '添加服务器'" 
      @ok="handleServerSubmit"
      :confirmLoading="submittingServer"
    >
      <a-form layout="vertical">
        <a-form-item label="服务器名称" required>
          <a-input v-model:value="serverForm.name" placeholder="请输入服务器名称" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="16">
            <a-form-item label="IP 地址" required>
              <a-input v-model:value="serverForm.ip" placeholder="127.0.0.1" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="端口" required>
              <a-input-number v-model:value="serverForm.port" :min="1" :max="65535" style="width: 100%" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="RCON 密码">
          <a-input-password v-model:value="serverForm.rcon_password" placeholder="留空则不修改" />
        </a-form-item>
        <a-form-item label="白名单模式">
          <a-switch v-model:checked="serverForm.enable_whitelist" />
          <span style="margin-left: 8px; color: rgba(0,0,0,0.45)">开启后，白名单玩家可豁免进服验证。若关闭且开启了进服验证，则仅限满足条件的玩家进入。</span>
        </a-form-item>
        <a-form-item label="进服验证">
          <a-switch v-model:checked="serverForm.verification_enabled" />
          <span style="margin-left: 8px; color: rgba(0,0,0,0.45)">开启后，玩家需满足最低等级与Rating。若同时开启白名单模式，则白名单玩家优先。</span>
        </a-form-item>
        <div v-if="serverForm.verification_enabled" style="background: rgba(0,0,0,0.02); padding: 16px; border-radius: 8px; margin-bottom: 16px; border: 1px solid rgba(0,0,0,0.06)">
          <a-row :gutter="16">
            <a-col :span="12">
               <a-form-item label="最低 Steam 等级" style="margin-bottom: 0">
                 <a-input-number v-model:value="serverForm.min_steam_level" :min="0" style="width: 100%" />
               </a-form-item>
            </a-col>
            <a-col :span="12">
               <a-form-item label="最低 GOKZ Rating" style="margin-bottom: 0">
                 <a-input-number v-model:value="serverForm.min_rating" :min="0" :step="0.1" style="width: 100%" />
               </a-form-item>
            </a-col>
          </a-row>
        </div>
      </a-form>
    </a-modal>

    <!-- Group Create/Edit Modal -->
    <a-modal 
      v-model:open="showGroupModal" 
      title="新建服务器组" 
      @ok="handleGroupSubmit"
    >
      <a-form layout="vertical">
        <a-form-item label="组名称" required>
          <a-input v-model:value="groupForm.name" placeholder="请输入服务器组名称" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Players Modal -->
    <a-modal 
      v-model:open="showPlayersModal" 
      :title="`在线玩家 - ${currentViewingServer?.name || ''}`" 
      :footer="null"
      width="800px"
      >
      <a-table 
        :dataSource="players" 
        :columns="playerColumns" 
        :pagination="false" 
        :loading="playersLoading"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button class="action-btn-kick" size="small" @click="showKickConfirm(record)">
                <template #icon><LogoutOutlined /></template>
                踢出
              </a-button>
              <a-button class="action-btn-ban" size="small" @click="showBanConfirm(record)">
                <template #icon><StopOutlined /></template>
                封禁
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-modal>

    <!-- Kick Confirm Modal -->
    <a-modal
      v-model:open="kickModal.visible"
      title="踢出确认"
      @ok="confirmKick"
      :confirmLoading="kickModal.submitting"
      :ok-text="'确认执行'"
      :cancel-text="'取消'"
      class="kick-confirm-modal"
      :ok-button-props="{ danger: true }"
    >
      <div class="modal-content-wrapper">
        <div class="user-info-card">
          <div class="avatar-placeholder"><UserOutlined /></div>
          <div class="info">
            <div class="label">准备踢出玩家</div>
            <div class="name">{{ kickModal.playerName }}</div>
            <div class="uid">ID: {{ kickModal.userid }}</div>
          </div>
        </div>
        
        <a-form layout="vertical" class="modern-form">
          <a-form-item label="处罚理由" required>
               <a-select v-model:value="kickModal.reason" style="width: 100%">
                 <a-select-option value="管理员请求">管理员请求</a-select-option>
                 <a-select-option value="消极游戏">消极游戏 / 挂机</a-select-option>
                 <a-select-option value="干扰他人">干扰他人游戏</a-select-option>
                 <a-select-option value="骂人/挑衅">不良言论 / 挑衅</a-select-option>
                 <a-select-option value="其他">其他</a-select-option>
               </a-select>
             <a-input v-if="kickModal.reason === '其他'" v-model:value="kickModal.customReason" placeholder="请输入具体理由" style="margin-top: 8px" />
          </a-form-item>
        </a-form>
      </div>
    </a-modal>

    <!-- Ban Confirm Modal -->
    <a-modal
      v-model:open="banModal.visible"
      title="严厉处罚 - 封禁"
      @ok="confirmBan"
      :confirmLoading="banModal.submitting"
      :ok-text="'实施封禁'"
      :cancel-text="'取消'"
      :width="540"
      class="ban-confirm-modal"
      :ok-button-props="{ danger: true }"
    >
      <div class="modal-content-wrapper">
        <div class="user-info-card ban-theme">
          <div class="avatar-placeholder"><LockOutlined /></div>
          <div class="info">
            <div class="label">正在对该玩家进行封禁</div>
            <div class="name">{{ banModal.playerName }}</div>
          </div>
        </div>

        <a-form layout="vertical" class="modern-form">
          <a-form-item label="封禁原因" required>
            <a-input v-model:value="banModal.reason" placeholder="请输入详细的封禁理由..." />
          </a-form-item>
          
          <div class="ban-settings-grid">
            <div class="setting-item">
              <div class="s-label">封禁时长</div>
              <a-select v-model:value="banModal.duration" style="width: 100%">
                <a-select-option :value="30">30 分钟</a-select-option>
                <a-select-option :value="60">1 小时</a-select-option>
                <a-select-option :value="1440">1 天</a-select-option>
                <a-select-option :value="10080">1 周</a-select-option>
                <a-select-option :value="43200">1 个月</a-select-option>
                <a-select-option :value="0">永久封禁</a-select-option>
              </a-select>
            </div>
            <div class="setting-item">
              <div class="s-label">处罚力度</div>
              <a-radio-group v-model:value="banModal.banType" button-style="solid" style="width: 100%; display: flex">
                <a-radio-button value="account" style="flex: 1; text-align: center">账号封禁</a-radio-button>
                <a-radio-button value="ip" style="flex: 1; text-align: center">IP 封禁</a-radio-button>
              </a-radio-group>
            </div>
          </div>

          <div class="ban-notice">
            <template v-if="banModal.banType === 'account'">
              <InfoCircleOutlined /> 封禁后，仅该 Steam 账号无法进入当前及关联服务器。
            </template>
            <template v-else>
              <WarningOutlined /> 连坐：封禁该 IP 下的所有账号，适用于打击严重违规者。
            </template>
          </div>
        </a-form>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useCommunityStore } from '@/composables/useCommunityStore'
import { 
  PlusOutlined, 
  DeleteOutlined, 
  UserOutlined, 
  LogoutOutlined, 
  StopOutlined, 
  LockOutlined,
  InfoCircleOutlined,
  WarningOutlined
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const store = useCommunityStore()
const { serverGroups, hasCommunity, removeServerGroup, removeServer, fetchServerGroups, addServerGroup } = store

onMounted(() => {
    fetchServerGroups()
})

const showGroupModal = ref(false)
const showServerModal = ref(false)
const showPlayersModal = ref(false)
const submittingServer = ref(false)
const playersLoading = ref(false)

const groupForm = reactive({
  name: ''
})

const serverForm = reactive({
  name: '',
  ip: '',
  port: 27015,
  rcon_password: '',
  verification_enabled: false,
  enable_whitelist: false,
  min_rating: 0.0,
  min_steam_level: 0
})

// 移除互斥逻辑，允许同时开启

const players = ref([])
const playerColumns = [
  { title: '玩家名', dataIndex: 'name', key: 'name' },
  { title: 'UserID', dataIndex: 'userid', key: 'userid' },
  { title: 'SteamID', dataIndex: 'steamid', key: 'steamid' },
  { title: 'Score', dataIndex: 'score', key: 'score' },
  { title: 'Time', dataIndex: 'time', key: 'time' },
  { title: '操作', key: 'action', width: 140 }
]

const currentEditingGroup = ref<any>(null)
const currentEditingServer = ref<any>(null)
const currentViewingServer = ref<any>(null)

// Modal states for Kick/Ban
const kickModal = reactive({
  visible: false,
  submitting: false,
  playerName: '',
  userid: '',
  reason: '管理员请求',
  customReason: ''
})

const banModal = reactive({
  visible: false,
  submitting: false,
  playerName: '',
  userid: '',
  reason: '违反服务器规则',
  duration: 43200,
  banType: 'account' as 'account' | 'ip'
})

const openCreateGroupModal = () => {
  currentEditingGroup.value = null
  groupForm.name = ''
  showGroupModal.value = true
}

const handleGroupSubmit = async () => {
  if (!groupForm.name) return message.warning('请输入名称')
  const res = await addServerGroup(groupForm.name)
  if (res.success) {
    message.success('创建成功')
    showGroupModal.value = false
  } else {
    message.error(res.message)
  }
}

const openAddServerModal = (groupId: any) => {
  currentEditingGroup.value = groupId
  currentEditingServer.value = null
  Object.assign(serverForm, {
    name: '',
    ip: '',
    port: 27015,
    rcon_password: '',
    verification_enabled: false,
    enable_whitelist: false,
    min_rating: 0.0,
    min_steam_level: 0
  })
  showServerModal.value = true
}

const openEditServerModal = (groupId: any, server: any) => {
  currentEditingGroup.value = groupId
  currentEditingServer.value = server
  Object.assign(serverForm, {
    name: server.name,
    ip: server.ip,
    port: server.port,
    rcon_password: '', // RCON Password usually not returned for security
    verification_enabled: !!server.verification_enabled,
    enable_whitelist: !!server.enable_whitelist,
    min_rating: server.min_rating || 0.0,
    min_steam_level: server.min_steam_level || 0
  })
  showServerModal.value = true
}

const handleServerSubmit = async () => {
  if (!serverForm.name || !serverForm.ip || !serverForm.port) {
    return message.warning('请填写完整信息')
  }

  submittingServer.value = true
  try {
    let res
    if (currentEditingServer.value) {
      res = await store.updateServer(currentEditingGroup.value, currentEditingServer.value.id, { ...serverForm })
    } else {
      res = await store.addServer(currentEditingGroup.value, { ...serverForm })
    }

    if (res.success) {
      message.success(currentEditingServer.value ? '更新成功' : '添加成功')
      showServerModal.value = false
    } else {
      message.error(res.message)
    }
  } finally {
    submittingServer.value = false
  }
}

const openPlayersModal = async (server: any) => {
  currentViewingServer.value = server
  players.value = []
  showPlayersModal.value = true
  playersLoading.value = true
  
  try {
    const res = await store.fetchPlayers(server.id)
    if (res.success) {
      players.value = res.data
    } else {
      message.error(res.message)
      showPlayersModal.value = false
    }
  } finally {
    playersLoading.value = false
  }
}

const showKickConfirm = (player: any) => {
  kickModal.playerName = player.name
  kickModal.userid = player.userid
  kickModal.reason = '管理员请求'
  kickModal.visible = true
}

const confirmKick = async () => {
  const finalReason = kickModal.reason === '其他' ? kickModal.customReason : kickModal.reason
  if (!finalReason) return message.warning('请输入理由')
  
  kickModal.submitting = true
  try {
    const res = await store.kickPlayer(currentViewingServer.value.id, kickModal.userid, finalReason)
    if (res.success) {
      message.success('已成功踢出玩家')
      kickModal.visible = false
      openPlayersModal(currentViewingServer.value)
    } else {
      message.error(res.message)
    }
  } finally {
    kickModal.submitting = false
  }
}

const showBanConfirm = (player: any) => {
  banModal.playerName = player.name
  banModal.userid = player.userid
  banModal.reason = '违反服务器规则'
  banModal.duration = 43200 // 1 month as default
  banModal.banType = 'account'
  banModal.visible = true
}

const confirmBan = async () => {
  if (!banModal.reason) return message.warning('请输入原因')
  
  banModal.submitting = true
  try {
    const res = await store.banPlayer(
      currentViewingServer.value.id, 
      banModal.userid, 
      banModal.duration, 
      banModal.reason,
      banModal.banType
    )
    if (res.success) {
      message.success('玩家已成功封禁')
      banModal.visible = false
      openPlayersModal(currentViewingServer.value)
    } else {
      message.error(res.message)
    }
  } finally {
    banModal.submitting = false
  }
}

const handleDeleteServer = async (groupId: any, serverId: any) => {
    const res = await removeServer(groupId, serverId)
    if (res.success) {
        message.success('服务器已删除')
    } else {
        message.error(res.message)
    }
}

const handleDeleteGroup = async (groupId: any) => {
    const res = await removeServerGroup(groupId)
    if (res.success) {
        message.success('服务器组已删除')
    } else {
        message.error(res.message)
    }
}
</script>

<style scoped>
.group-list {
  margin-top: 16px;
}

/* Action Buttons Styles */
.action-btn-kick {
    background: #fff1f0;
    border-color: #ffccc7;
    color: #ff4d4f;
    transition: all 0.3s cubic-bezier(0.645, 0.045, 0.355, 1);
}
.action-btn-kick:hover {
    background: #ff4d4f;
    color: white;
    border-color: #ff4d4f;
    box-shadow: 0 4px 12px rgba(255, 77, 79, 0.35);
}

.action-btn-ban {
    background: #f0f5ff;
    border-color: #adc6ff;
    color: #2f54eb;
    transition: all 0.3s cubic-bezier(0.645, 0.045, 0.355, 1);
}
.action-btn-ban:hover {
    background: #2f54eb;
    color: white;
    border-color: #2f54eb;
    box-shadow: 0 4px 12px rgba(47, 84, 235, 0.35);
}

/* Modal Content Styling */
.modal-content-wrapper {
    padding: 8px 0;
}

.user-info-card {
    display: flex;
    align-items: center;
    background: linear-gradient(135deg, #fff1f0 0%, #ffffff 100%);
    padding: 16px;
    border-radius: 12px;
    border: 1px solid #ffccc7;
    margin-bottom: 24px;
}

.user-info-card.ban-theme {
    background: linear-gradient(135deg, #f0f5ff 0%, #ffffff 100%);
    border-color: #adc6ff;
}

.avatar-placeholder {
    width: 48px;
    height: 48px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    color: #ff4d4f;
    box-shadow: 0 4px 8px rgba(0,0,0,0.05);
    margin-right: 16px;
}

.ban-theme .avatar-placeholder {
    color: #2f54eb;
}

.user-info-card .info .label {
    font-size: 12px;
    color: rgba(0,0,0,0.45);
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.user-info-card .info .name {
    font-size: 18px;
    font-weight: 700;
    color: #262626;
    line-height: 1.2;
}

.user-info-card .info .uid {
    font-size: 12px;
    color: rgba(0,0,0,0.45);
    font-family: monospace;
}

.ban-settings-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 20px;
}

.s-label {
    font-size: 13px;
    font-weight: 500;
    margin-bottom: 8px;
    color: #595959;
}

.ban-notice {
    background: #fffbe6;
    border: 1px solid #ffe58f;
    padding: 10px 14px;
    border-radius: 8px;
    font-size: 13px;
    color: #876800;
    display: flex;
    align-items: center;
    gap: 8px;
}

.kick-confirm-modal :deep(.ant-modal-footer .ant-btn-primary) {
    border-radius: 6px !important;
    height: 38px !important;
}

.ban-confirm-modal :deep(.ant-modal-footer .ant-btn-primary) {
    background: #2f54eb !important;
    border-color: #2f54eb !important;
    border-radius: 6px !important;
    height: 38px !important;
}
</style>
