class BankAccountModel {
  final String id;
  final String merchantId;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final DateTime? createdAt;

  BankAccountModel({
    required this.id,
    required this.merchantId,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.createdAt,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      accountName: json['account_name'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(
              (json['created_at'] as String).endsWith('Z') || (json['created_at'] as String).contains('+')
                  ? json['created_at'] as String
                  : '${json['created_at']}Z'
            ).toLocal() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
    };
  }
}
