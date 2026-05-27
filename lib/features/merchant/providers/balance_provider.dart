import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/services/supabase_service.dart';
import 'package:lastbite/core/models/merchant_transaction_model.dart';
import 'package:lastbite/core/models/bank_account_model.dart';

class BalanceState {
  final double balance;
  final List<MerchantTransactionModel> transactions;
  final List<BankAccountModel> bankAccounts;
  final bool isLoading;

  BalanceState({
    this.balance = 0.0,
    this.transactions = const [],
    this.bankAccounts = const [],
    this.isLoading = true,
  });

  BalanceState copyWith({
    double? balance,
    List<MerchantTransactionModel>? transactions,
    List<BankAccountModel>? bankAccounts,
    bool? isLoading,
  }) {
    return BalanceState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BalanceNotifier extends Notifier<BalanceState> {
  final _supabase = SupabaseService().client;

  @override
  BalanceState build() {
    // Delay fetch to avoid blocking initialization
    Future.microtask(() => _fetchData());
    return BalanceState();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final merchantRes = await _supabase
          .from('merchants')
          .select('id, balance')
          .eq('user_id', user.id)
          .maybeSingle();

      if (merchantRes == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final merchantId = merchantRes['id'] as String;
      final balance = (merchantRes['balance'] as num).toDouble();

      final txRes = await _supabase
          .from('merchant_transactions')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final transactions = (txRes as List)
          .map((e) => MerchantTransactionModel.fromJson(e))
          .toList();

      final bankRes = await _supabase
          .from('merchant_bank_accounts')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final bankAccounts = (bankRes as List)
          .map((e) => BankAccountModel.fromJson(e))
          .toList();

      state = state.copyWith(
        balance: balance,
        transactions: transactions,
        bankAccounts: bankAccounts,
        isLoading: false,
      );
    } catch (e) {
      print('Error fetching balance data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchData();
  }

  Future<void> addBankAccount(String bankName, String accountNumber, String accountName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not logged in';

      final merchantRes = await _supabase
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (merchantRes == null) throw 'Merchant not found';
      final merchantId = merchantRes['id'] as String;

      await _supabase.from('merchant_bank_accounts').insert({
        'merchant_id': merchantId,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
      });

      await refresh();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> requestWithdrawal(double amount, String bankAccountId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not logged in';

      final merchantRes = await _supabase
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (merchantRes == null) throw 'Merchant not found';
      final merchantId = merchantRes['id'] as String;

      await _supabase.rpc('request_withdrawal', params: {
        'p_merchant_id': merchantId,
        'p_amount': amount,
        'p_bank_account_id': bankAccountId,
      });

      await refresh();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

final balanceProvider = NotifierProvider<BalanceNotifier, BalanceState>(() {
  return BalanceNotifier();
});
