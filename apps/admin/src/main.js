import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import LoginView from './views/LoginView.vue';
import DashboardView from './views/DashboardView.vue';
import './style.css';
import { getToken } from './api/auth';
const router = createRouter({
    history: createWebHistory(),
    routes: [
        { path: '/', redirect: '/dashboard' },
        { path: '/login', component: LoginView, meta: { guest: true } },
        { path: '/dashboard', component: DashboardView, meta: { requiresAuth: true } },
    ],
});
router.beforeEach((to) => {
    if (to.meta.requiresAuth && !getToken())
        return '/login';
    if (to.meta.guest && getToken())
        return '/dashboard';
});
createApp(App).use(router).mount('#app');
