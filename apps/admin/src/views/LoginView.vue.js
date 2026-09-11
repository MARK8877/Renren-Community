import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { adminLogin } from '../api/auth';
const account = ref('');
const password = ref('');
const error = ref('');
const loading = ref(false);
const router = useRouter();
async function submit() {
    error.value = '';
    if (!account.value || !password.value) {
        error.value = '请输入账号和密码';
        return;
    }
    loading.value = true;
    try {
        await adminLogin(account.value.trim(), password.value);
        await router.push('/dashboard');
    }
    catch (reason) {
        error.value = reason instanceof Error ? reason.message : '登录失败';
    }
    finally {
        loading.value = false;
    }
}
const __VLS_ctx = {
    ...{},
    ...{},
};
let __VLS_components;
let __VLS_intrinsics;
let __VLS_directives;
__VLS_asFunctionalElement1(__VLS_intrinsics.main, __VLS_intrinsics.main)({
    ...{ class: "centered-page" },
});
/** @type {__VLS_StyleScopedClasses['centered-page']} */ ;
__VLS_asFunctionalElement1(__VLS_intrinsics.form, __VLS_intrinsics.form)({
    ...{ onSubmit: (__VLS_ctx.submit) },
    ...{ class: "card login-card" },
});
/** @type {__VLS_StyleScopedClasses['card']} */ ;
/** @type {__VLS_StyleScopedClasses['login-card']} */ ;
__VLS_asFunctionalElement1(__VLS_intrinsics.h1, __VLS_intrinsics.h1)({});
__VLS_asFunctionalElement1(__VLS_intrinsics.label, __VLS_intrinsics.label)({});
__VLS_asFunctionalElement1(__VLS_intrinsics.input)({
    autocomplete: "username",
});
(__VLS_ctx.account);
__VLS_asFunctionalElement1(__VLS_intrinsics.label, __VLS_intrinsics.label)({});
__VLS_asFunctionalElement1(__VLS_intrinsics.input)({
    type: "password",
    autocomplete: "current-password",
});
(__VLS_ctx.password);
if (__VLS_ctx.error) {
    __VLS_asFunctionalElement1(__VLS_intrinsics.p, __VLS_intrinsics.p)({
        ...{ class: "error" },
    });
    /** @type {__VLS_StyleScopedClasses['error']} */ ;
    (__VLS_ctx.error);
}
__VLS_asFunctionalElement1(__VLS_intrinsics.button, __VLS_intrinsics.button)({
    type: "submit",
    disabled: (__VLS_ctx.loading),
});
(__VLS_ctx.loading ? '登录中…' : '登录');
// @ts-ignore
[submit, account, password, error, error, loading, loading,];
const __VLS_export = (await import('vue')).defineComponent({});
export default {};
