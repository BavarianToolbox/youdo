import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.stripeCustomerId,
    this.stripePaymentMethodId,
    this.hasPaymentMethod = false,
    this.onboardingComplete = false,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.ydBalance = 0.0,
    this.totalEarned = 0.0,
    this.totalLost = 0.0,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? stripeCustomerId;
  final String? stripePaymentMethodId;
  final bool hasPaymentMethod;
  final bool onboardingComplete;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final double ydBalance;
  final double totalEarned;
  final double totalLost;

  factory AppUser.fromJson(Map<String, dynamic> data) {
    return AppUser(
      uid: data['id'] as String,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '',
      stripeCustomerId: data['stripe_customer_id'] as String?,
      stripePaymentMethodId: data['stripe_payment_method_id'] as String?,
      hasPaymentMethod: data['has_payment_method'] as bool? ?? false,
      onboardingComplete: data['onboarding_complete'] as bool? ?? false,
      notificationsEnabled: data['notifications_enabled'] as bool? ?? true,
      soundEnabled: data['sound_enabled'] as bool? ?? true,
      hapticsEnabled: data['haptics_enabled'] as bool? ?? true,
      ydBalance: (data['yd_balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (data['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalLost: (data['total_lost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'display_name': displayName,
      'has_payment_method': hasPaymentMethod,
      'onboarding_complete': onboardingComplete,
      'notifications_enabled': notificationsEnabled,
      'sound_enabled': soundEnabled,
      'haptics_enabled': hapticsEnabled,
      'yd_balance': ydBalance,
      'total_earned': totalEarned,
      'total_lost': totalLost,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? stripeCustomerId,
    String? stripePaymentMethodId,
    bool? hasPaymentMethod,
    bool? onboardingComplete,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
    double? ydBalance,
    double? totalEarned,
    double? totalLost,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripePaymentMethodId:
          stripePaymentMethodId ?? this.stripePaymentMethodId,
      hasPaymentMethod: hasPaymentMethod ?? this.hasPaymentMethod,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      ydBalance: ydBalance ?? this.ydBalance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalLost: totalLost ?? this.totalLost,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    displayName,
    hasPaymentMethod,
    onboardingComplete,
  ];
}
