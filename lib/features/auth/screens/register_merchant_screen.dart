import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import 'package:geolocator/geolocator.dart';
import 'package:lastbite/features/merchant/providers/merchant_provider.dart'; 
import 'package:solar_icons/solar_icons.dart';

class RegisterMerchantScreen extends ConsumerStatefulWidget {
  const RegisterMerchantScreen({super.key});

  @override
  ConsumerState<RegisterMerchantScreen> createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends ConsumerState<RegisterMerchantScreen> {
  bool _obscurePassword = true;
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedCategory;
  String? _selectedLocation;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Makanan Berat',
    'Kue & Roti',
    'Minuman',
    'Camilan',
    'Bahan Mentah'
  ];
  
  final List<String> _locations = [
    'Sumbersari',
    'Kaliwates',
    'Patrang',
    'Ajung',
    'Arjasa'
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
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
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      icon,
                      color: Colors.grey.shade500,
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
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hintText,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9).withOpacity(0.4),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: const Color(0xFFC8E6C9),
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(
                hintText,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              icon: Icon(
                icon,
                color: Colors.grey.shade500,
                size: 20,
              ),
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF2D4A2D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(merchantProvider, (previous, next) {
      if (!next.isLoading && next.hasError) {
         if (mounted) {
           setState(() {
             _isSubmitting = false;
           });
         }
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (previous?.isLoading == true && !next.isLoading && !next.hasError && _isSubmitting) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('🎉 Mitra Terdaftar!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
              content: const Text(
                'Selamat, Toko Anda berhasil didaftarkan!\nSaatnya mulai menyelamatkan sisa makanan.',
                textAlign: TextAlign.center,
              ),
              actions: [
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.pop(); // Close dialog
                          context.go('/merchant/dashboard'); 
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text('Ke Dashboard Toko', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          context.pop(); // Close dialog
                          context.go('/home'); 
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text('Ke Dashboard Pembeli', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      }
    });

    final isMerchantLoading = ref.watch(merchantProvider).isLoading;

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
          
          // ── Back Button ──────────────────────────────────────
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: const Icon(SolarIconsOutline.altArrowLeft, color: Color(0xFF1A3C1A)),
              ),
            ),
          ),

          // ── Main scrollable content ────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 80), // Space for top blob and back button

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
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A3C1A),
                                  letterSpacing: -0.3,
                                ),
                                children: [
                                  TextSpan(text: '🌱 ', style: TextStyle(color: Color(0xFF2E7D32))),
                                  TextSpan(text: 'Join the Rescue!'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtitle
                            const Text(
                              'Barang mendekati expired dan stok berlebih?\nJangan dibuang! Tingkatkan pemasukan dan\nmulai selamatkan! 🌱',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B7C6B),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Fields
                            _buildTextField(
                              label: 'Nama Usaha',
                              hintText: 'Toko Kue Bunda',
                              icon: SolarIconsOutline.shop,
                              controller: _storeNameController,
                              isFocusedStyle: true,
                            ),
                            
                            _buildDropdownField(
                              label: 'Kategori Bisnis',
                              hintText: 'Pilih Kategori',
                              icon: SolarIconsOutline.tag,
                              value: _selectedCategory,
                              items: _categories,
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategory = val;
                                });
                              },
                            ),

                            _buildDropdownField(
                              label: 'Lokasi (Area Jember)',
                              hintText: 'Pilih kecamatan',
                              icon: SolarIconsOutline.mapPoint,
                              value: _selectedLocation,
                              items: _locations,
                              onChanged: (val) {
                                setState(() {
                                  _selectedLocation = val;
                                });
                              },
                            ),

                            _buildTextField(
                              label: 'Nama Pemilik Usaha',
                              hintText: 'Masukkan Nama Lengkap',
                              icon: SolarIconsOutline.user, // Using person instead of phone for logical UI
                              controller: _ownerNameController,
                            ),

                            _buildTextField(
                              label: 'Nomor Kantor',
                              hintText: '+62 812 3456 xxxx',
                              icon: SolarIconsOutline.phone,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),

                            _buildTextField(
                              label: 'Password',
                              hintText: 'Masukkan password',
                              icon: SolarIconsOutline.eye,
                              controller: _passwordController,
                              isPassword: true,
                            ),

                            const SizedBox(height: 12),

                            // ── CTA Button ───────────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: (_isFetchingLocation || isMerchantLoading) ? null : () async {
                                  if (_storeNameController.text.trim().isEmpty || 
                                      _ownerNameController.text.trim().isEmpty || 
                                      _phoneController.text.trim().isEmpty || 
                                      _passwordController.text.isEmpty ||
                                      _selectedCategory == null || 
                                      _selectedLocation == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Semua kolom wajib diisi!', style: TextStyle(fontWeight: FontWeight.w500)),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  if (!RegExp(r'^\+62[0-9]{9,13}$').hasMatch(_phoneController.text.trim())) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Nomor kantor harus diawali +62 dan 9-13 digit.', style: TextStyle(fontWeight: FontWeight.w500)),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() {
                                    _isFetchingLocation = true;
                                    _isSubmitting = true;
                                  });

                                  try {
                                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                    if (!serviceEnabled) throw 'Akses GPS dinonaktifkan. Anda harus menyalakan lokasi di HP Anda.';

                                    LocationPermission permission = await Geolocator.checkPermission();
                                    if (permission == LocationPermission.denied) {
                                      permission = await Geolocator.requestPermission();
                                      if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak.';
                                    }

                                    if (permission == LocationPermission.deniedForever) {
                                      throw 'Izin lokasi diblokir permanen. Ubah lewat setting HP Anda.';
                                    }

                                    Position position = await Geolocator.getCurrentPosition();
                                    
                                    await ref.read(merchantProvider.notifier).registerMerchant(
                                      storeName: _storeNameController.text.trim(),
                                      category: _selectedCategory!,
                                      locationName: _selectedLocation!,
                                      ownerName: _ownerNameController.text.trim(),
                                      officePhone: _phoneController.text.trim(),
                                      password: _passwordController.text,
                                      latitude: position.latitude,
                                      longitude: position.longitude,
                                    );

                                  } catch (e) {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isFetchingLocation = false;
                                        if (ref.read(merchantProvider).hasError) {
                                            _isSubmitting = false;
                                        }
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: (_isFetchingLocation || isMerchantLoading)
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Buat Akun Mitra',
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
                                  'Sudah punya akun mitra? ',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.go('/login');
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
                            const SizedBox(height: 40),
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
