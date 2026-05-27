import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:solar_icons/solar_icons.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isFetching = true;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('name, phone, user_picture_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _emailController.text = user.email ?? '';
          if (userData != null) {
            _nameController.text = userData['name'] ?? '';
            _phoneController.text = userData['phone'] ?? '';
            _existingImageUrl = userData['user_picture_url'];
          }
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat profil: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Sesi berakhir, harap login ulang.';

      String? newImageUrl = _existingImageUrl;

      // 1. Upload gambar jika ada yang baru
      if (_imageFile != null) {
        newImageUrl = await CloudinaryService.uploadImage(
          _imageFile!,
          folder: 'profiles',
        );
      }

      // 2. Update Auth (Email dan Data Metadata)
      final emailChanged = _emailController.text != user.email;
      
      await supabase.auth.updateUser(
        UserAttributes(
          email: emailChanged ? _emailController.text : null,
          data: {
            'name': _nameController.text,
            'avatar_url': newImageUrl,
          },
        ),
      );

      // 3. Update public.users
      await supabase.from('users').update({
        'name': _nameController.text,
        'phone': _phoneController.text.isNotEmpty ? _phoneController.text : null,
        'user_picture_url': newImageUrl,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailChanged 
                  ? 'Profil berhasil diperbarui. Silakan cek email kamu untuk mengonfirmasi email baru.' 
                  : 'Profil berhasil diperbarui!',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
        context.pop(true); // Return true to signal a refresh is needed
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
          'Ubah Profil',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3B382D)),
        ),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- PROFILE PICTURE ---
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                              image: _imageFile != null
                                  ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                                  : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                      ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                                      : DecorationImage(image: NetworkImage('https://ui-avatars.com/api/?name=${_nameController.text}&background=16A34A&color=fff&size=150'), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(SolarIconsOutline.camera, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- FORM FIELDS ---
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nama Lengkap',
                      hint: 'Misal: Andi Pratama',
                      icon: SolarIconsOutline.user,
                      validator: (value) => value == null || value.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Nomor Handphone',
                      hint: 'Misal: +6281234567890',
                      icon: SolarIconsOutline.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.startsWith('+62')) return 'Gunakan awalan +62';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Alamat Email',
                      hint: 'Misal: andi@contoh.com',
                      icon: SolarIconsOutline.letter,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
                        if (!value.contains('@')) return 'Format email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(SolarIconsOutline.infoCircle, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Jika kamu mengubah email, kami akan mengirimkan tautan konfirmasi ke email yang baru.',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/change-password'),
                        icon: const Icon(SolarIconsOutline.lockPassword, size: 20),
                        label: const Text('Ganti Kata Sandi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D312E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0A9A0), fontSize: 14, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Icon(icon, color: const Color(0xFFA0A9A0), size: 22),
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
          ),
        ),
      ],
    );
  }
}
