class MerchantTransactionModel {
  final String id;
  final String merchantId;
  final String? orderId;
  final String? bankAccountId;
  final String type; // 'credit', 'debit'
  final double amount;
  final String? status; // 'pending', 'completed', 'rejected'
  final String? proofImage;
  final DateTime? createdAt;

  MerchantTransactionModel({
    required this.id,
    required this.merchantId,
    this.orderId,
    this.bankAccountId,
    required this.type,
    required this.amount,
    this.status,
    this.proofImage,
    this.createdAt,
  });

  factory MerchantTransactionModel.fromJson(Map<String, dynamic> json) {
    return MerchantTransactionModel(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      orderId: json['order_id'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String?,
      proofImage: json['proof_image'] as String?,
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
      if (orderId != null) 'order_id': orderId,
      if (bankAccountId != null) 'bank_account_id': bankAccountId,
      'type': type,
      'amount': amount,
      if (status != null) 'status': status,
      if (proofImage != null) 'proof_image': proofImage,
    };
  }
}
