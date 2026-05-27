import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/features/merchant/providers/balance_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  String? _selectedBankAccountId;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for new bank account
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  bool _isAddingBank = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _submitWithdrawal(double maxBalance) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedBankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Silakan pilih rekening bank tujuan'), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    final amountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountStr.isEmpty) return;

    final amount = double.tryParse(amountStr) ?? 0;
    if (amount < 20000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Minimal penarikan adalah Rp 20.000'), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    if (amount > maxBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Saldo tidak mencukupi'), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(balanceProvider.notifier).requestWithdrawal(amount, _selectedBankAccountId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penarikan berhasil diajukan'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengajukan penarikan: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addNewBankAccount() async {
    final bankName = _bankNameController.text.trim();
    final accNumber = _accountNumberController.text.trim();
    final accName = _accountNameController.text.trim();

    if (bankName.isEmpty || accNumber.isEmpty || accName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Semua data rekening harus diisi'), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(balanceProvider.notifier).addBankAccount(bankName, accNumber, accName);
      setState(() {
        _isAddingBank = false;
        _bankNameController.clear();
        _accountNumberController.clear();
        _accountNameController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rekening berhasil ditambahkan'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah rekening: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(balanceProvider);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Tarik Saldo',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFamily: 'DMSans',
          ),
        ),
      ),
      body: balanceState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F943B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Saldo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo Aktif', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D4A2D))),
                          Text(
                            currencyFormat.format(balanceState.balance),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Input Nominal
                    const Text('Nominal Penarikan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Minimal Rp 20.000',
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 16),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F943B), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Masukkan nominal penarikan';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Pilih Rekening
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rekening Tujuan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                        if (balanceState.bankAccounts.length < 3 && !_isAddingBank)
                          TextButton.icon(
                            onPressed: () => setState(() => _isAddingBank = true),
                            icon: const Icon(SolarIconsOutline.addCircle, size: 16),
                            label: const Text('Tambah Rekening'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F943B)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isAddingBank) ...[
                      // Form Tambah Rekening
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _bankNameController,
                              decoration: const InputDecoration(labelText: 'Nama Bank (contoh: BCA, Mandiri)'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _accountNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Nomor Rekening'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _accountNameController,
                              decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _isAddingBank = false),
                                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: _isSubmitting ? null : _addNewBankAccount,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F943B)),
                                  child: _isSubmitting
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Simpan', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ] else ...[
                      if (balanceState.bankAccounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Belum ada rekening yang ditambahkan. Silakan tambah rekening terlebih dahulu.', style: TextStyle(color: Colors.red)),
                        )
                      else
                        ...balanceState.bankAccounts.map((bank) {
                          return RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${bank.bankName} - ${bank.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('a.n. ${bank.accountName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            value: bank.id,
                            groupValue: _selectedBankAccountId,
                            activeColor: const Color(0xFF0F943B),
                            onChanged: (value) {
                              setState(() => _selectedBankAccountId = value);
                            },
                          );
                        }).toList(),
                    ],

                    const SizedBox(height: 48),

                    // Tombol Tarik
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _isAddingBank || balanceState.bankAccounts.isEmpty
                            ? null
                            : () => _submitWithdrawal(balanceState.balance),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F943B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isSubmitting && !_isAddingBank
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text(
                                'Ajukan Penarikan',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
