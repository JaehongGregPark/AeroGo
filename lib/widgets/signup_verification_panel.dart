import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// "회원가입/이메일 인증" screen. Talks directly to the FastAPI backend's
/// `POST /auth/register` and `POST /auth/resend-verification` (see
/// backend/app/main.py). It does not call `/auth/login` or store the
/// session token that login now returns -- there is currently no signed-in
/// state in the Flutter app.
class SignupVerificationPanel extends StatefulWidget {
  const SignupVerificationPanel({super.key});

  @override
  State<SignupVerificationPanel> createState() =>
      _SignupVerificationPanelState();
}

class _SignupVerificationPanelState extends State<SignupVerificationPanel> {
  final apiBaseUrlController = TextEditingController(
    text: 'http://localhost:8000',
  );
  final emailController = TextEditingController();
  final displayNameController = TextEditingController();
  final passwordController = TextEditingController();
  bool termsAccepted = false;
  bool loading = false;
  String message = '메일 아이디로 가입하면 인증 메일이 발송됩니다.';

  @override
  void dispose() {
    apiBaseUrlController.dispose();
    emailController.dispose();
    displayNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_email_read),
                    const SizedBox(width: 12),
                    Text(
                      '회원가입/이메일 인증',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: apiBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API 서버 주소',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '메일 아이디',
                    hintText: 'user@example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: '표시 이름',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    helperText: '8자 이상',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: termsAccepted,
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            termsAccepted = value ?? false;
                          });
                        },
                  title: const Text('서비스 이용 약관에 동의합니다.'),
                ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: loading ? null : _register,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: const Text('회원가입'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: loading ? null : _resendVerification,
                      icon: const Icon(Icons.refresh),
                      label: const Text('인증메일 재발송'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!termsAccepted) {
      setState(() {
        message = '약관 동의가 필요합니다.';
      });
      return;
    }
    await _post(
      '/auth/register',
      {
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'display_name': displayNameController.text.trim(),
        'terms_accepted': termsAccepted,
      },
    );
  }

  Future<void> _resendVerification() async {
    await _post(
      '/auth/resend-verification',
      {'email': emailController.text.trim()},
    );
  }

  Future<void> _post(String path, Map<String, Object?> body) async {
    setState(() {
      loading = true;
      message = '요청을 처리하는 중입니다.';
    });

    try {
      final baseUrl = apiBaseUrlController.text.trim().replaceAll(
            RegExp(r'/$'),
            '',
          );
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final verifyUrl = data['development_verify_url'];
          message = [
            data['message'] ?? '요청이 완료되었습니다.',
            if (verifyUrl != null) '개발용 인증 링크: $verifyUrl',
          ].join('\n');
        } else {
          message = data['detail']?.toString() ?? '요청에 실패했습니다.';
        }
      });
    } catch (error) {
      setState(() {
        message = 'API 서버에 연결할 수 없습니다. 서버 주소와 실행 상태를 확인해 주세요.\n$error';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }
}
