<script setup lang="ts">
import { useRouter } from 'vue-router'
import { getAdminUser, logout } from '../api/auth'
const router = useRouter()
const user = getAdminUser()
async function signOut(){ logout(); await router.replace('/login') }
const metrics = [
  { label: '新增用户', value: '--' },
  { label: '活跃用户', value: '--' },
  { label: '今日发布', value: '--' },
  { label: '待审核', value: '--' },
]
</script>

<template>
  <div class="admin-layout">
    <aside><h2>CreatorHub</h2><p>{{ user?.nickname }}</p><nav>数据概览</nav><button @click="signOut">退出登录</button></aside>
    <main>
      <h1>数据概览</h1>
      <section class="metric-grid">
        <article v-for="item in metrics" :key="item.label" class="card">
          <span>{{ item.label }}</span><strong>{{ item.value }}</strong>
        </article>
      </section>
    </main>
  </div>
</template>
