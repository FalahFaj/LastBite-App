class PaymentModel {
  final String id;
  final String orderId;
  final String? method; // e.g. 'transfer'
  final String? paymentProof;
  final String? status; // 'pending', 'verified', 'rejected'
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    this.method,
    this.paymentProof,
    this.status,
    this.createdAt,
  });

  PaymentModel copyWith({
    String? id,
    String? orderId,
    String? method,
    String? paymentProof,
    String? status,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      method: method ?? this.method,
      paymentProof: paymentProof ?? this.paymentProof,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      method: json['method'] as String?,
      paymentProof: json['payment_proof'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      if (method != null) 'method': method,
      if (paymentProof != null) 'payment_proof': paymentProof,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
