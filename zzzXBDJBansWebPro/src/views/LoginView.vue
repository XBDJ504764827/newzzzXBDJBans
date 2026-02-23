<template>
  <div class="login-container">
    <div class="login-content">
      <div class="login-header">
        <img alt="logo" class="logo" src="https://gw.alipayobjects.com/zos/rmsportal/KDpgvguMpGfqaHPjicRK.svg" />
        <span class="title">zzzXBDJBans</span>
      </div>
      <div class="login-desc">专业的封禁管理系统解决方案</div>
      
      <a-card :bordered="false" class="login-card">
        <a-tabs v-model:activeKey="activeKey" centered>
          <a-tab-pane key="account" tab="账号密码登录">
            <a-form
              layout="vertical"
              :model="loginForm"
              @finish="handleSubmit"
            >
              <a-form-item
                name="username"
                :rules="[{ required: true, message: '请输入用户名!' }]"
              >
                <a-input v-model:value="loginForm.username" size="large" placeholder="用户名: admin">
                  <template #prefix><UserOutlined /></template>
                </a-input>
              </a-form-item>
              
              <a-form-item
                name="password"
                :rules="[{ required: true, message: '请输入密码!' }]"
              >
                <a-input-password v-model:value="loginForm.password" size="large" placeholder="密码: 123456">
                  <template #prefix><LockOutlined /></template>
                </a-input-password>
              </a-form-item>
              
              <div style="margin-bottom: 24px">
                <a-checkbox v-model:checked="autoLogin">自动登录</a-checkbox>
                <a style="float: right">忘记密码</a>
              </div>
              
              <a-form-item>
                <a-button type="primary" html-type="submit" size="large" block :loading="loading">
                  登录
                </a-button>
              </a-form-item>
            </a-form>
          </a-tab-pane>
        </a-tabs>
      </a-card>
      
      <div class="login-footer">
        <div class="links">
          <a href="/bans">公共封禁库</a>
          <a href="/apply">申请白名单</a>
          <a href="/whitelist-status">状态查询</a>
        </div>
        <div class="copyright">
          Copyright © 2026 Antigravity
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { UserOutlined, LockOutlined } from '@ant-design/icons-vue'
import { useAuthStore } from '@/composables/useAuthStore'
import { message } from 'ant-design-vue'

const router = useRouter()
const { login } = useAuthStore()

const activeKey = ref('account')
const loading = ref(false)
const autoLogin = ref(true)

const loginForm = reactive({
  username: '',
  password: ''
})

const handleSubmit = async () => {
  loading.value = true
  try {
    const res = await login(loginForm.username, loginForm.password)
    if (res.success) {
      message.success('登录成功！')
      router.push('/admin')
    } else {
      message.error(res.message || '登录失败')
    }
  } catch (error) {
    message.error('登录发生错误')
  } finally {
    loading.value = false
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
  justify-content: center;
}

.login-header {
  margin-bottom: 12px;
}

.login-header .logo {
  height: 44px;
  vertical-align: top;
  margin-right: 16px;
  border-style: none;
}

.login-header .title {
  font-size: 33px;
  color: rgba(0, 0, 0, 0.85);
  font-family: Avenir, 'Helvetica Neue', Arial, Helvetica, sans-serif;
  font-weight: 600;
  position: relative;
  top: 2px;
}

.login-desc {
  font-size: 14px;
  color: rgba(0, 0, 0, 0.45);
  margin-top: 12px;
  margin-bottom: 40px;
}

.login-card {
  width: 368px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  border-radius: 6px;
}

.login-footer {
  margin-top: 48px;
  text-align: center;
}

.login-footer .links {
  margin-bottom: 8px;
}

.login-footer .links a {
  color: rgba(0, 0, 0, 0.45);
  margin: 0 16px;
  transition: all 0.3s;
}

.login-footer .links a:hover {
  color: rgba(0, 0, 0, 0.85);
}

.login-footer .copyright {
  color: rgba(0, 0, 0, 0.45);
  font-size: 14px;
}
</style>
