import 'package:flutter/material.dart';
import '../auth/auth_api.dart';
import '../auth/auth_session.dart';
import 'register_screen.dart';

const _loginInk = Color(0xFF17213A);
const _loginPurple = Color(0xFF6857E5);
const _loginCoral = Color(0xFFFF6B78);
const _loginCanvas = Color(0xFFF6F7FB);
const _loginField = Color(0xFFF1F2F7);
const _testLoginIdentifier = 'test@example.com';
const _testLoginPassword = 'Test123456!';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final AuthSession session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final identifier = TextEditingController(text: _testLoginIdentifier);
  final password = TextEditingController(text: _testLoginPassword);
  bool loading = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.session.login(identifier.text.trim(), password.text);
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void closePage() {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF73798A)),
      floatingLabelStyle: const TextStyle(
        color: _loginPurple,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, size: 21),
      prefixIconColor: const Color(0xFF73798A),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _loginField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _loginPurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _loginCoral),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _loginCoral, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _loginCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PixelCommunityMark(onClose: closePage),
                    const SizedBox(height: 34),
                    const Text(
                      '欢迎回到\n像素社区',
                      key: Key('login-title'),
                      style: TextStyle(
                        color: _loginInk,
                        fontSize: 38,
                        height: 1.12,
                        letterSpacing: -1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '登录后继续发现内容，和同频的人一起创作。',
                      style: TextStyle(
                        color: Color(0xFF73798A),
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -5,
                          top: 34,
                          child: Container(
                            width: 13,
                            height: 13,
                            color: _loginCoral,
                          ),
                        ),
                        Positioned(
                          left: -5,
                          bottom: 42,
                          child: Container(
                            width: 10,
                            height: 10,
                            color: const Color(0xFFFFCB57),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFE8E9F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D17213A),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const Key('login-identifier'),
                                  controller: identifier,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                    AutofillHints.telephoneNumber,
                                  ],
                                  decoration: fieldDecoration(
                                    label: '手机号或邮箱',
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '请输入手机号或邮箱'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const Key('login-password'),
                                  controller: password,
                                  obscureText: obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: loading
                                      ? null
                                      : (_) => submit(),
                                  decoration: fieldDecoration(
                                    label: '密码',
                                    icon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      key: const Key('toggle-login-password'),
                                      tooltip: obscure ? '显示密码' : '隐藏密码',
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.length < 8
                                      ? '密码至少 8 位'
                                      : null,
                                ),
                                if (error != null)
                                  Container(
                                    key: const Key('login-error'),
                                    margin: const EdgeInsets.only(top: 14),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: Color(0xFFB83848),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    key: const Key('login-submit'),
                                    onPressed: loading ? null : submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _loginInk,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(
                                        0xFFADB1BC,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox.square(
                                            dimension: 21,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('登录'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  key: const Key('open-register'),
                                  onPressed: loading
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RegisterScreen(
                                              session: widget.session,
                                            ),
                                          ),
                                        ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _loginPurple,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text('没有账号？立即注册'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelCommunityMark extends StatelessWidget {
  const _PixelCommunityMark({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(width: 17, height: 17, color: _loginPurple),
              ),
              Positioned(
                right: 0,
                top: 4,
                child: Container(width: 14, height: 14, color: _loginCoral),
              ),
              Positioned(
                left: 4,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  color: const Color(0xFFFFCB57),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 2,
                child: Container(width: 15, height: 15, color: _loginInk),
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        const Text(
          '像素社区',
          style: TextStyle(
            color: _loginInk,
            fontSize: 18,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        IconButton(
          key: const Key('close-login-page'),
          tooltip: '关闭登录页',
          onPressed: onClose,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            backgroundColor: Colors.white,
            foregroundColor: _loginInk,
            side: const BorderSide(color: Color(0xFFE5E7EF)),
          ),
          icon: const Icon(Icons.close_rounded, size: 22),
        ),
      ],
    );
  }
}
