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
    this.totalEarned = 0.0,
    this.totalLost = 0.0,
    this.fcmToken,
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
  final double totalEarned;
  final double totalLost;
  final String? fcmToken;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      stripeCustomerId: data['stripeCustomerId'] as String?,
      stripePaymentMethodId: data['stripePaymentMethodId'] as String?,
      hasPaymentMethod: data['hasPaymentMethod'] as bool? ?? false,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      soundEnabled: data['soundEnabled'] as bool? ?? true,
      hapticsEnabled: data['hapticsEnabled'] as bool? ?? true,
      totalEarned: (data['totalEarned'] as num?)?.toDouble() ?? 0.0,
      totalLost: (data['totalLost'] as num?)?.toDouble() ?? 0.0,
      fcmToken: data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'hasPaymentMethod': hasPaymentMethod,
      'onboardingComplete': onboardingComplete,
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'hapticsEnabled': hapticsEnabled,
      'totalEarned': totalEarned,
      'totalLost': totalLost,
      if (fcmToken != null) 'fcmToken': fcmToken,
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
    double? totalEarned,
    double? totalLost,
    String? fcmToken,
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
      totalEarned: totalEarned ?? this.totalEarned,
      totalLost: totalLost ?? this.totalLost,
      fcmToken: fcmToken ?? this.fcmToken,
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
