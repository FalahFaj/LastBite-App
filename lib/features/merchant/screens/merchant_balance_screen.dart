import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/features/merchant/providers/balance_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class MerchantBalanceScreen extends ConsumerWidget {
  const MerchantBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceState = ref.watch(balanceProvider);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Saldo Toko',
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
          : RefreshIndicator(
              onRefresh: () => ref.read(balanceProvider.notifier).refresh(),
              color: const Color(0xFF0F943B),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Kartu Saldo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF147A36), Color(0xFF0F5A28)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Saldo Aktif',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(balanceState.balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DMSans',
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.push('/merchant/withdraw');
                            },
                            icon: const Icon(SolarIconsOutline.wallet, color: Color(0xFF0F5A28)),
                            label: const Text(
                              'Tarik Saldo',
                              style: TextStyle(
                                color: Color(0xFF0F5A28),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F5A28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Riwayat Transaksi
                  const Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                      fontFamily: 'DMSans',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (balanceState.transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(SolarIconsOutline.bill, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada transaksi',
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...balanceState.transactions.map((tx) {
                      final isCredit = tx.type == 'credit';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCredit ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isCredit ? SolarIconsOutline.altArrowDown : SolarIconsOutline.altArrowUp,
                                color: isCredit ? Colors.green.shade600 : Colors.orange.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCredit ? 'Pemasukan Pesanan' : 'Penarikan Saldo',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tx.createdAt != null ? dateFormat.format(tx.createdAt!) : '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                  if (!isCredit && tx.status != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tx.status == 'pending' ? 'Sedang Diproses' : (tx.status == 'completed' ? 'Berhasil' : 'Ditolak'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: tx.status == 'pending' ? Colors.orange.shade600 : (tx.status == 'completed' ? Colors.green.shade600 : Colors.red.shade600),
                                      ),
                                    ),
                                    if (tx.proofImage != null && tx.proofImage!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              clipBehavior: Clip.antiAlias,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AppBar(
                                                    elevation: 0,
                                                    backgroundColor: Colors.white,
                                                    title: const Text('Bukti Transfer', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                                                    automaticallyImplyLeading: false,
                                                    actions: [
                                                      IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context))
                                                    ],
                                                  ),
                                                  Flexible(
                                                    child: SingleChildScrollView(
                                                      child: Image.network(
                                                        tx.proofImage!,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (_, __, ___) => const Padding(
                                                          padding: EdgeInsets.all(32.0),
                                                          child: Icon(SolarIconsOutline.galleryRemove, size: 48, color: Colors.grey),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text('Lihat Bukti Transfer', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '${isCredit ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isCredit ? Colors.green.shade700 : Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
    );
  }
}
