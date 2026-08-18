class SubscriptionStatus {
  static const String trial = 'trial';
  static const String active = 'active';
  static const String expired = 'expired';
  static const String grace = 'grace';
  static const String none = 'none';
}

/// Single-row snapshot of the user's trial/subscription state, kept on
/// device (`subscription_state` table, id = 'current'). The server
/// (`verifySubscription` Cloud Function) never stores this — it only
/// answers "is this purchase token currently active" on request, so this
/// row is the only place the app's own view of "am I allowed in" lives.
class SubscriptionState {
  final DateTime? trialStartedAt;
  final String status;
  final String? productId;
  final String? purchaseToken;
  final String? purchaseOrderId;
  final DateTime? expiryTime;
  final DateTime? lastVerifiedAt;
  final DateTime? lastVerificationAttemptAt;
  final bool autoRenewing;
  final DateTime updatedAt;

  /// The latest wall-clock [DateTime.now()] this device has ever recorded
  /// while evaluating subscription/trial access. Anything is free to move
  /// this forward; nothing should ever move it backward. Used by
  /// [SubscriptionService.resolveAccess] to detect a device clock that has
  /// been set backward to replay an already-elapsed trial/grace window —
  /// `now` observed earlier than this is treated as untrustworthy.
  final DateTime? maxObservedAt;

  const SubscriptionState({
    this.trialStartedAt,
    required this.status,
    this.productId,
    this.purchaseToken,
    this.purchaseOrderId,
    this.expiryTime,
    this.lastVerifiedAt,
    this.lastVerificationAttemptAt,
    this.autoRenewing = false,
    required this.updatedAt,
    this.maxObservedAt,
  });

  SubscriptionState copyWith({
    DateTime? trialStartedAt,
    String? status,
    String? productId,
    String? purchaseToken,
    String? purchaseOrderId,
    DateTime? expiryTime,
    DateTime? lastVerifiedAt,
    DateTime? lastVerificationAttemptAt,
    bool? autoRenewing,
    DateTime? updatedAt,
    DateTime? maxObservedAt,
  }) {
    return SubscriptionState(
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      status: status ?? this.status,
      productId: productId ?? this.productId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      expiryTime: expiryTime ?? this.expiryTime,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      lastVerificationAttemptAt:
          lastVerificationAttemptAt ?? this.lastVerificationAttemptAt,
      autoRenewing: autoRenewing ?? this.autoRenewing,
      updatedAt: updatedAt ?? this.updatedAt,
      maxObservedAt: maxObservedAt ?? this.maxObservedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': 'current',
    'trialStartedAt': trialStartedAt?.toIso8601String(),
    'status': status,
    'productId': productId,
    'purchaseToken': purchaseToken,
    'purchaseOrderId': purchaseOrderId,
    'expiryTimeMillis': expiryTime?.millisecondsSinceEpoch.toString(),
    'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
    'lastVerificationAttemptAt': lastVerificationAttemptAt?.toIso8601String(),
    'autoRenewing': autoRenewing ? 1 : 0,
    'updatedAt': updatedAt.toIso8601String(),
    'maxObservedAt': maxObservedAt?.toIso8601String(),
  };

  factory SubscriptionState.fromJson(Map<String, Object?> json) {
    final expiryMillis = json['expiryTimeMillis'] as String?;
    return SubscriptionState(
      trialStartedAt: (json['trialStartedAt'] as String?) != null
          ? DateTime.parse(json['trialStartedAt'] as String)
          : null,
      status: json['status'] as String? ?? SubscriptionStatus.none,
      productId: json['productId'] as String?,
      purchaseToken: json['purchaseToken'] as String?,
      purchaseOrderId: json['purchaseOrderId'] as String?,
      expiryTime: (expiryMillis != null && expiryMillis.isNotEmpty)
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(expiryMillis))
          : null,
      lastVerifiedAt: (json['lastVerifiedAt'] as String?) != null
          ? DateTime.parse(json['lastVerifiedAt'] as String)
          : null,
      lastVerificationAttemptAt:
          (json['lastVerificationAttemptAt'] as String?) != null
          ? DateTime.parse(json['lastVerificationAttemptAt'] as String)
          : null,
      autoRenewing: (json['autoRenewing'] as int? ?? 0) == 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      maxObservedAt: (json['maxObservedAt'] as String?) != null
          ? DateTime.parse(json['maxObservedAt'] as String)
          : null,
    );
  }
}
