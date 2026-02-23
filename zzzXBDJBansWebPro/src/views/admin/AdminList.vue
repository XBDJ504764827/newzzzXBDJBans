<template>
  <div class="page-container">
    <div class="table-toolbar">
      <div class="left">
        <h2 style="font-size: 20px; font-weight: 600; margin: 0">管理员管理</h2>
        <div style="margin-top: 4px; color: rgba(0,0,0,0.45); font-size: 14px">
          当前身份: <span style="color: rgba(0,0,0,0.85); font-weight: 500">{{ currentUser?.username }}</span>
          <a-tag :color="currentUser?.role === 'super_admin' ? 'purple' : 'blue'" style="margin-left: 8px">
            {{ currentUser?.role === 'super_admin' ? '系统级管理员' : '普通管理员' }}
          </a-tag>
        </div>
      </div>
      <div class="right">
        <a-button v-if="isSystemAdmin" type="primary" @click="openAddModal">
          <template #icon><PlusOutlined /></template>
          新增管理员
        </a-button>
      </div>
    </div>

    <a-card :bordered="false">
      <a-table
        :columns="columns"
        :data-source="adminList"
        row-key="id"
        :pagination="{ pageSize: 15 }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'role'">
            <a-tag :color="record.role === 'super_admin' ? 'purple' : 'blue'">
              {{ record.role === 'super_admin' ? '系统级管理员' : '普通管理员' }}
            </a-tag>
          </template>

          <template v-else-if="column.key === 'action'">
            <a-space v-if="isSystemAdmin || record.id === currentUser?.id">
              <a-button type="link" size="small" @click="openEditModal(record)">编辑</a-button>
              <a-popconfirm
                v-if="isSystemAdmin && record.id !== currentUser?.id"
                title="确定要删除该管理员吗？"
                @confirm="handleDelete(record.id)"
              >
                <a-button type="link" size="small" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>

          <template v-else-if="column.key === 'time'">
            {{ new Date(record.createTime).toLocaleDateString() }}
          </template>

          <template v-else-if="column.key === 'remark'">
            {{ record.remark || '-' }}
          </template>

          <template v-else-if="column.key === 'steamId'">
            <span class="mono-text">{{ record.steamId || '-' }}</span>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal
      v-model:open="showModal"
      :title="editMode ? '编辑管理员' : '新增管理员'"
      @ok="handleModalOk"
      :confirmLoading="modalLoading"
    >
      <a-form layout="vertical" :model="adminForm">
        <a-form-item label="用户名" required>
          <a-input v-model:value="adminForm.username" :disabled="editMode" />
        </a-form-item>
        <a-form-item :label="editMode ? '重置密码 (留空不修改)' : '密码'" :required="!editMode">
          <a-input-password v-model:value="adminForm.password" />
        </a-form-item>
        <a-form-item label="角色" required v-if="isSystemAdmin">
          <a-select v-model:value="adminForm.role">
            <a-select-option value="admin">普通管理员</a-select-option>
            <a-select-option value="super_admin">系统级管理员</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="Steam ID">
          <a-input v-model:value="adminForm.steamId" placeholder="STEAM_0:0:xxx" />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea v-model:value="adminForm.remark" :rows="2" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useAuthStore } from '@/composables/useAuthStore'
import { PlusOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const { adminList, isSystemAdmin, addAdmin, updateAdmin, deleteAdmin, currentUser, fetchAdmins } = useAuthStore()

const columns = [
  { title: '用户名', dataIndex: 'username', key: 'username' },
  { title: '身份', key: 'role' },
  { title: '备注', key: 'remark' },
  { title: 'SteamID', key: 'steamId' },
  { title: '创建时间', key: 'time' },
  { title: '操作', key: 'action', align: 'right' as const },
]

onMounted(() => {
    fetchAdmins()
})

const showModal = ref(false)
const modalLoading = ref(false)
const editMode = ref(false)
const currentAdminId = ref<any>(null)

const adminForm = reactive({
  username: '',
  password: '',
  role: 'admin',
  steamId: '',
  remark: ''
})

const openAddModal = () => {
  editMode.value = false
  currentAdminId.value = null
  Object.assign(adminForm, {
    username: '',
    password: '',
    role: 'admin',
    steamId: '',
    remark: ''
  })
  showModal.value = true
}

const openEditModal = (admin: any) => {
  editMode.value = true
  currentAdminId.value = admin.id
  Object.assign(adminForm, {
    username: admin.username,
    password: '',
    role: admin.role,
    steamId: admin.steamId || '',
    remark: admin.remark || ''
  })
  showModal.value = true
}

const handleModalOk = async () => {
  if (!adminForm.username) return message.warning('请输入用户名')
  if (!editMode.value && !adminForm.password) return message.warning('请输入密码')
  
  modalLoading.value = true
  try {
    let res
    if (editMode.value) {
      res = await updateAdmin(currentAdminId.value, adminForm)
    } else {
      res = await addAdmin(adminForm)
    }

    if (res.success) {
      message.success(editMode.value ? '已更新' : '已添加')
      showModal.value = false
    } else {
      message.error(res.message)
    }
  } finally {
    modalLoading.value = false
  }
}

const handleDelete = async (id: any) => {
  const res = await deleteAdmin(id)
  if (res.success) {
    message.success('已删除')
  } else {
    message.error(res.message)
  }
}
</script>
