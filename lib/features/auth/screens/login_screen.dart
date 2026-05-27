import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/features/auth/providers/auth_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // Listen to changes for error handling
    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          if (ModalRoute.of(context)?.isCurrent != true) return;

          String errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
          final errorStr = error.toString().toLowerCase();

          if (errorStr.contains('invalid login credentials') ||
              errorStr.contains('invalid_credentials')) {
            errorMessage = 'Email atau password salah.';
          } else if (errorStr.contains('invalid format') ||
              errorStr.contains('unable to validate email')) {
            errorMessage =
                'Format email tidak valid atau alamat email tidak dikenali.';
          } else if (errorStr.contains('network') ||
              errorStr.contains('socket') ||
              errorStr.contains('timeout')) {
            errorMessage = 'Terdapat masalah koneksi internet.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F2),
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // ── Background Vectors ──────────────────────────────────────
          Positioned(
            top: -320,
            left: 55,
            right: -120,
            child: Image.asset(
              'assets/kembangan/Vector1.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          Positioned(
            top: -130,
            left: 30,
            right: -50,
            child: Image.asset(
              'assets/kembangan/Vector2.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          Positioned(
            top: -60,
            left: 0,
            right: -10,
            child: Image.asset(
              'assets/kembangan/Vector3.png',
              fit: BoxFit.fitWidth,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              child: Image.asset(
                'assets/kembangan/Vector_bawah.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          // ── Main scrollable content ────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 200),

                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A3C1A),
                          letterSpacing: -0.3,
                        ),
                        children: [
                          TextSpan(text: 'Welcome back, Hero! '),
                          TextSpan(text: '🌱'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    const Text(
                      'Nikmati diskon, kurangi sampah, dan\njadilah pahlawan ekonomi lokal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7C6B),
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Email field ──────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Alamat E-mail',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF2D4A2D),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF0F6F0),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        hintText: 'johndoe@email.com',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: const BorderSide(
                            color: Color(0xFFC8E6C9),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E7D32),
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(
                            SolarIconsOutline.letter,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Password field ───────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF2D4A2D),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFE8F5E9).withOpacity(0.4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        hintText: 'Masukkan password',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: const BorderSide(
                            color: Color(0xFFC8E6C9),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E7D32),
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Icon(
                              _obscurePassword
                                  ? SolarIconsOutline.eye
                                  : SolarIconsOutline.eyeClosed,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── CTA Button ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_emailController.text.trim().isEmpty ||
                                    _passwordController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Isi email dan password terlebih dahulu!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final emailText = _emailController.text.trim();
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(emailText)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Format email tidak valid. Periksa kembali penulisan alamat email.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // if (_passwordController.text.length <= 8) {
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //      SnackBar(
                                //       content: const Text('Password terlalu pendek. Gunakan minimal 8 karakter.', style: TextStyle(fontWeight: FontWeight.w500)),
                                //       backgroundColor: Colors.red.shade600,
                                //       behavior: SnackBarBehavior.floating,
                                //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                //     ),
                                //   );
                                //   return;
                                // }

                                ref
                                    .read(authNotifierProvider.notifier)
                                    .login(emailText, _passwordController.text);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Mulai Penyelamatan!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Register link ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.push('/register');
                          },
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(
                                0xFF007AFF,
                              ), // Changed to blue to match screenshot
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
