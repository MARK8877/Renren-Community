import 'package:flutter/material.dart';
import '../auth/auth_api.dart';
import '../auth/auth_session.dart';

const _registerInk = Color(0xFF17213A);
const _registerPurple = Color(0xFF6857E5);
const _registerCoral = Color(0xFFFF6B78);
const _registerCanvas = Color(0xFFF6F7FB);
const _registerField = Color(0xFFF1F2F7);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.session});
  final AuthSession session;
  @override
  State<RegisterScreen> createState() => _State();
}

class _State extends State<RegisterScreen> {
  final key = GlobalKey<FormState>(),
      nickname = TextEditingController(),
      id = TextEditingController(),
      password = TextEditingController();
  bool agreed = false, loading = false;
  String? error;
  @override
  void dispose() {
    nickname.dispose();
    id.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!key.currentState!.validate()) return;
    if (!agreed) {
      setState(() => error = '请先同意用户协议和隐私政策');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.session.register(
        id.text.trim(),
        password.text,
        nickname.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF73798A)),
        floatingLabelStyle: const TextStyle(
          color: _registerPurple,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, size: 21),
        prefixIconColor: const Color(0xFF73798A),
        filled: true,
        fillColor: _registerField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
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
          borderSide: const BorderSide(color: _registerPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _registerCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _registerCoral, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _registerCanvas,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                minHeight: constraints.maxHeight - 44,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('close-register-page'),
                        tooltip: '返回登录',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(44),
                          backgroundColor: Colors.white,
                          foregroundColor: _registerInk,
                          side: const BorderSide(color: Color(0xFFE5E7EF)),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                      const Spacer(),
                      const _RegisterPixelMark(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '加入像素社区',
                    style: TextStyle(
                      color: _registerInk,
                      fontSize: 35,
                      height: 1.15,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '创建账号，找到同频的创作者和兴趣社区。',
                    style: TextStyle(
                      color: Color(0xFF73798A),
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -5,
                        top: 52,
                        child: Container(
                          width: 12,
                          height: 12,
                          color: _registerCoral,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                          key: key,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                key: const Key('register-nickname'),
                                controller: nickname,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.nickname],
                                decoration: fieldDecoration(
                                  '昵称',
                                  Icons.person_outline_rounded,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? '请输入昵称'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('register-identifier'),
                                controller: id,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                  AutofillHints.telephoneNumber,
                                ],
                                decoration: fieldDecoration(
                                  '手机号或邮箱',
                                  Icons.alternate_email_rounded,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? '请输入手机号或邮箱'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('register-password'),
                                controller: password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onFieldSubmitted: loading
                                    ? null
                                    : (_) => submit(),
                                decoration: fieldDecoration(
                                  '密码',
                                  Icons.lock_outline_rounded,
                                ),
                                validator: (v) => v == null || v.length < 8
                                    ? '密码至少 8 位'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  key: const Key('register-agreement'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  value: agreed,
                                  activeColor: _registerPurple,
                                  checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => agreed = v ?? false),
                                  title: const Text(
                                    '同意用户协议和隐私政策',
                                    style: TextStyle(
                                      color: Color(0xFF616778),
                                      fontSize: 13,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ),
                              if (error != null)
                                Container(
                                  key: const Key('register-error'),
                                  margin: const EdgeInsets.only(top: 8),
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
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 56,
                                child: FilledButton(
                                  key: const Key('register-submit'),
                                  onPressed: loading ? null : submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _registerInk,
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
                                      : const Text('注册'),
                                ),
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

class _RegisterPixelMark extends StatelessWidget {
  const _RegisterPixelMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(width: 13, height: 13, color: _registerPurple),
            ),
            Positioned(
              right: 0,
              top: 3,
              child: Container(width: 11, height: 11, color: _registerCoral),
            ),
            Positioned(
              left: 3,
              bottom: 0,
              child: Container(
                width: 11,
                height: 11,
                color: const Color(0xFFFFCB57),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(width: 11, height: 11, color: _registerInk),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      const Text(
        '像素社区',
        style: TextStyle(
          color: _registerInk,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
