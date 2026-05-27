import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null || user.email == null) {
        throw 'Harap login terlebih dahulu.';
      }

      // Verifikasi password lama dengan mencoba login
      try {
        await supabase.auth.signInWithPassword(
          email: user.email!,
          password: _oldPasswordController.text,
        );
      } on AuthException catch (e) {
        if (e.message.toLowerCase().contains('invalid login credentials')) {
          throw 'Kata sandi lama salah.';
        }
        rethrow;
      }

      // Jika berhasil verifikasi, ubah ke password baru
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kata sandi berhasil diubah!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(SolarIconsOutline.altArrowLeft, color: Color(0xFF2D312E), size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Ubah Kata Sandi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3B382D)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buat Kata Sandi Baru',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2D312E)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan kata sandi baru kamu unik dan tidak mudah ditebak untuk menjaga keamanan akun.',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A938C), height: 1.5),
              ),
              const SizedBox(height: 32),

              _buildPasswordField(
                controller: _oldPasswordController,
                label: 'Kata Sandi Lama',
                hint: 'Masukkan kata sandi lama',
                obscure: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Kata sandi lama tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Kata Sandi Baru',
                hint: 'Masukkan kata sandi baru',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Kata sandi baru tidak boleh kosong';
                  if (value.length < 6) return 'Kata sandi minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Kata Sandi Baru',
                hint: 'Ulangi kata sandi baru',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Konfirmasi kata sandi tidak boleh kosong';
                  if (value != _newPasswordController.text) return 'Kata sandi tidak cocok';
                  return null;
                },
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D312E)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D312E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0A9A0), fontSize: 14, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE8F0E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE8F0E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? SolarIconsOutline.eyeClosed : SolarIconsOutline.eye,
                color: const Color(0xFFA0A9A0),
                size: 22,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
