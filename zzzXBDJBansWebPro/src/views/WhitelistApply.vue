<template>
  <div class="login-container" style="justify-content: flex-start; padding-top: 80px">
    <div class="login-content">
      <div class="login-header">
        <h1 class="title">白名单申请</h1>
      </div>
      <div class="login-desc">填写您的信息，等待管理员审核</div>

      <a-alert
        message="无需申请的情况"
        type="warning"
        show-icon
        style="width: 400px; margin-bottom: 24px"
      >
        <template #description>
          如果您满足 <b>Rating >= 3.0</b> 并且 <b>Steam等级 >= 1</b>，您可以直接进入服务器，无需申请白名单！
        </template>
      </a-alert>

      <a-card :bordered="false" class="login-card" style="width: 400px">
        <template v-if="submitted">
          <a-result
            status="success"
            title="申请已提交"
            sub-title="请等待管理员审核，审核通过后您即可进入服务器"
          >
            <template #extra>
              <a-button type="primary" @click="router.push('/')">返回首页</a-button>
            </template>
          </a-result>
        </template>

        <a-form
          v-else
          layout="vertical"
          :model="formData"
          @finish="handleSubmit"
        >
          <a-form-item
            label="Steam ID"
            name="steam_id"
            :rules="[{ required: true, message: '请输入 Steam ID!' }]"
            :help="playerCheckError || '支持 SteamID64、SteamID2、SteamID3 或个人资料链接'"
            :validate-status="playerCheckError ? 'error' : ''"
          >
            <a-input
              v-model:value="formData.steam_id"
              size="large"
              placeholder="76561198000000000"
              @change="handleSteamIdChange"
            >
              <template #suffix>
                <LoadingOutlined v-if="checkingPlayer" />
              </template>
            </a-input>
          </a-form-item>

          <!-- 玩家确认区域 -->
          <div v-if="playerInfo" class="player-info-box">
             <a-space align="start">
               <a-avatar :src="playerInfo.avatarfull" :size="48" />
               <div>
                 <div style="font-size: 12px; color: rgba(0,0,0,0.45)">检测到玩家</div>
                 <div style="font-weight: 600; font-size: 16px">{{ playerInfo.personaname }}</div>
               </div>
             </a-space>

             <div v-if="confirmationStatus === 'pending'" style="margin-top: 12px">
               <a-space>
                 <a-button type="primary" size="small" @click="confirmIsMe">是本人</a-button>
                 <a-button size="small" @click="confirmNotMe">不是本人</a-button>
               </a-space>
             </div>
             
             <div v-else-if="confirmationStatus === 'confirmed_me'" style="margin-top: 12px; color: #52c41a">
               <CheckCircleFilled /> 已确认为本人
             </div>
             <div v-else-if="confirmationStatus === 'confirmed_other'" style="margin-top: 12px; color: #faad14">
               请手动填写昵称
             </div>
          </div>

          <a-form-item
            label="游戏昵称"
            name="name"
            :rules="[{ required: true, message: '请输入游戏昵称!' }]"
            :help="nicknameHelp"
          >
            <a-input
              v-model:value="formData.name"
              size="large"
              :disabled="isNameDisabled"
              placeholder="您在游戏中的昵称"
            />
          </a-form-item>

          <a-form-item>
            <a-button 
              type="primary" 
              html-type="submit" 
              size="large" 
              block 
              :loading="submitting"
              :disabled="confirmationStatus === 'none' || confirmationStatus === 'pending'"
            >
              提交申请
            </a-button>
          </a-form-item>

          <div style="text-align: center">
            <router-link to="/whitelist-status">
              已提交申请？点击查看审核状态 →
            </router-link>
          </div>
        </a-form>
      </a-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { LoadingOutlined, CheckCircleFilled } from '@ant-design/icons-vue'
import api from '@/utils/api'
import { debounce } from 'lodash-es'
import { message } from 'ant-design-vue'

const router = useRouter()
const formData = reactive({
  steam_id: '',
  name: ''
})

const submitting = ref(false)
const submitted = ref(false)
const checkingPlayer = ref(false)
const playerInfo = ref<any>(null)
const playerCheckError = ref('')
const confirmationStatus = ref('none')

const isNameDisabled = computed(() => {
  return confirmationStatus.value !== 'confirmed_other'
})

const nicknameHelp = computed(() => {
  if (confirmationStatus.value === 'none') return '请先填写 Steam ID'
  if (confirmationStatus.value === 'pending') return '请确认是否为本人'
  if (confirmationStatus.value === 'confirmed_me') return '已自动填写 Steam 昵称'
  return '请手动填写游戏昵称'
})

const checkPlayer = async (val: string) => {
  if (!val || val.length < 5) {
    playerInfo.value = null
    playerCheckError.value = ''
    confirmationStatus.value = 'none'
    formData.name = ''
    return
  }

  checkingPlayer.value = true
  playerCheckError.value = ''
  playerInfo.value = null
  confirmationStatus.value = 'none'
  formData.name = ''
  
  try {
    const res = await api.get('/whitelist/player-info', {
      params: { steam_id: val }
    })
    playerInfo.value = res.data
    confirmationStatus.value = 'pending'
  } catch (err: any) {
    if (err.response?.status === 404) {
       playerCheckError.value = '未找到玩家，请检查 Steam ID'
    } else {
       message.error('检查玩家信息失败')
    }
  } finally {
    checkingPlayer.value = false
  }
}

const debouncedCheck = debounce(checkPlayer, 800)

const handleSteamIdChange = () => {
  debouncedCheck(formData.steam_id)
}

const confirmIsMe = () => {
  if (playerInfo.value) {
    formData.name = playerInfo.value.personaname
    confirmationStatus.value = 'confirmed_me'
  }
}

const confirmNotMe = () => {
  formData.name = ''
  confirmationStatus.value = 'confirmed_other'
}

const handleSubmit = async () => {
  submitting.value = true
  try {
    const res = await api.post('/whitelist/apply', formData)
    if (res.status === 201) {
      submitted.value = true
      message.success('提交成功！')
    }
  } catch (err: any) {
    const errorMsg = err.response?.data?.error || '提交失败，请稍后重试'
    message.error(errorMsg)
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: auto;
  background: #f0f2f5;
  background-image: url('https://gw.alipayobjects.com/zos/rmsportal/TVjtqqS9V52qfRk4P68y.svg');
  background-repeat: no-repeat;
  background-position: center 110px;
  background-size: 100%;
}

.login-content {
  flex: 1;
  padding: 32px 0;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.login-header {
  margin-bottom: 12px;
}

.login-header .title {
  font-size: 33px;
  color: rgba(0, 0, 0, 0.85);
  font-family: Avenir, 'Helvetica Neue', Arial, Helvetica, sans-serif;
  font-weight: 600;
}

.login-desc {
  font-size: 14px;
  color: rgba(0, 0, 0, 0.45);
  margin-top: 12px;
  margin-bottom: 40px;
}

.login-card {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  border-radius: 6px;
}

.player-info-box {
  margin-bottom: 24px;
  padding: 16px;
  background: #f9f9f9;
  border-radius: 6px;
  border: 1px dashed #d9d9d9;
}
</style>
