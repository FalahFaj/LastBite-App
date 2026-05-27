import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/features/auth/providers/auth_provider.dart';
import 'package:solar_icons/solar_icons.dart';


class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  bool _obscurePassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool isFocusedStyle = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF2D4A2D),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isFocusedStyle
                ? const Color(0xFFF0F6F0)
                : const Color(0xFFE8F5E9).withOpacity(0.4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
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
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        _obscurePassword
                            ? SolarIconsOutline.eyeClosed
                            : SolarIconsOutline.eye,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(icon, color: Colors.grey.shade500, size: 20),
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading && !next.hasError) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Column(
                children: [
                  Icon(
                    SolarIconsOutline.letterUnread,
                    color: Color(0xFF2E7D32),
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Cek Email Kamu!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ],
              ),
              content: const Text(
                'Pendaftaran berhasil. Silakan buka email kamu dan klik link verifikasi yang baru saja kami kirim (Cek juga folder Spam/Junk jika tidak ada).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7C6B), height: 1.5),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      'OK, Mengerti',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }

      next.whenOrNull(
        error: (error, stackTrace) {
          if (ModalRoute.of(context)?.isCurrent != true) return;

          final errorStr = error.toString().toLowerCase();
          String errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';

          if (errorStr.contains('already_registered') ||
              errorStr.contains('user_already_exists') ||
              errorStr.contains('already registered')) {
            errorMessage = 'Email sudah terdaftar.';
          } else if (errorStr.contains('invalid format') ||
              errorStr.contains('unable to validate email')) {
            errorMessage =
                'Format email tidak valid atau alamat email tidak dikenali.';
          } else if (errorStr.contains('weak_password') ||
              errorStr.contains('password should be at least')) {
            errorMessage = 'Password terlalu lemah, minimal 6 karakter.';
          } else if (errorStr.contains('phone_format_check')) {
            errorMessage = 'Format nomor HP salah. Gunakan awalan +62.';
          } else if (errorStr.contains('unique_phone') ||
              errorStr.contains('phone number already')) {
            errorMessage = 'Nomor HP sudah digunakan oleh akun lain.';
          } else if (errorStr.contains('invalid_credentials')) {
            errorMessage = 'Email atau password salah.';
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
            child: Image.asset('assets/kembangan/Vector1.png', fit: BoxFit.fitWidth),
          ),
          Positioned(
            top: -130,
            left: 30,
            right: -50,
            child: Image.asset('assets/kembangan/Vector2.png', fit: BoxFit.fitWidth),
          ),
          Positioned(
            top: -60,
            left: 0,
            right: -10,
            child: Image.asset('assets/kembangan/Vector3.png', fit: BoxFit.fitWidth),
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
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 85),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 36),

                            // Title
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A3C1A),
                                  letterSpacing: -0.3,
                                ),
                                children: [
                                  TextSpan(
                                    text: '🌱 ',
                                    style: TextStyle(color: Color(0xFF2E7D32)),
                                  ),
                                  TextSpan(text: 'Join the Rescue!'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtitle
                            const Text(
                              'Nikmati diskon, kurangi sampah, dan\njadilah pahlawan ekonomi lokal.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B7C6B),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 42),

                            // Fields
                            _buildTextField(
                              label: 'Nama Lengkap',
                              hintText: 'John Doe',
                              icon: SolarIconsOutline.user,
                              controller: _nameController,
                              isFocusedStyle: true,
                            ),
                            _buildTextField(
                              label: 'Alamat E-mail',
                              hintText: 'johndoe@email.com',
                              icon: SolarIconsOutline.letter,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _buildTextField(
                              label: 'Password',
                              hintText: 'Masukkan password',
                              icon: Icons
                                  .remove_red_eye_outlined, // Eye icon used dynamically
                              controller: _passwordController,
                              isPassword: true,
                            ),
                            _buildTextField(
                              label: 'Nomor HP',
                              hintText: '+62 812 3456 xxxx',
                              icon: SolarIconsOutline.phone,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),

                            const SizedBox(height: 32),

                            // ── CTA Button ───────────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        if (_nameController.text
                                                .trim()
                                                .isEmpty ||
                                            _emailController.text
                                                .trim()
                                                .isEmpty ||
                                            _passwordController.text.isEmpty ||
                                            _phoneController.text
                                                .trim()
                                                .isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Semua kolom pendaftaran harus diisi',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final emailText = _emailController.text
                                            .trim();
                                        if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                        ).hasMatch(emailText)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Format email tidak valid. Periksa kembali penulisan alamat email.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        if (_passwordController.text.length <
                                            8) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Password terlalu pendek. Gunakan minimal 8 karakter.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final phoneText = _phoneController.text
                                            .trim();
                                        if (!RegExp(
                                          r'^\+62[0-9]{9,13}$',
                                        ).hasMatch(phoneText)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Format nomor HP salah. Gunakan awalan +62 diikuti 9-13 angka.',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        ref
                                            .read(authNotifierProvider.notifier)
                                            .register(
                                              name: _nameController.text.trim(),
                                              email: _emailController.text
                                                  .trim(),
                                              password:
                                                  _passwordController.text,
                                              phone: phoneText,
                                            );
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

                            // ── Login link ────────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.pop(); // Go back to login
                                  },
                                  child: const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF007AFF),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFF007AFF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // ── Yellow Mitra Button ────────────────────────────────────
                            // Container(
                            //   width: double.infinity,
                            //   height: 54,
                            //   decoration: BoxDecoration(
                            //     color: const Color(0xFFFDD835),
                            //     borderRadius: BorderRadius.circular(50),
                            //     border: Border.all(
                            //       color: Colors.black87,
                            //       width: 1.5,
                            //     ),
                            //     boxShadow: const [
                            //       BoxShadow(
                            //         color: Colors.black87,
                            //         offset: Offset(0, 4),
                            //         blurRadius: 0,
                            //       ),
                            //     ],
                            //   ),
                            //   child: Material(
                            //     color: Colors.transparent,
                            //     child: InkWell(
                            //       borderRadius: BorderRadius.circular(50),
                            //       onTap: () {
                            //         context.push('/register-merchant');
                            //       },
                            //       child: Row(
                            //         mainAxisAlignment: MainAxisAlignment.center,
                            //         children: [
                            //           const Icon(
                            //             SolarIconsOutline.shop,
                            //             color: Colors.black87,
                            //             size: 22,
                            //           ),
                            //           const SizedBox(width: 10),
                            //           const Text(
                            //             'Jadi Mitra ',
                            //             style: TextStyle(
                            //               color: Colors.black87,
                            //               fontSize: 15,
                            //               fontWeight: FontWeight.w500,
                            //             ),
                            //           ),
                            //           const Text(
                            //             'LastBite',
                            //             style: TextStyle(
                            //               color: Colors.black87,
                            //               fontSize: 15,
                            //               fontWeight: FontWeight.w900,
                            //             ),
                            //           ),
                            //         ],
                            //       ),
                            //     ),
                            //   ),
                            // ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
