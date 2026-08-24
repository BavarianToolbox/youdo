import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Replace with your Stripe test publishable key (pk_test_...) from stripe.com
// Pass at build time: flutter run --dart-define=STRIPE_PK=pk_test_yourkey
const _stripePublishableKey = String.fromEnvironment(
  'STRIPE_PK',
  defaultValue: 'pk_test_placeholder_replace_me',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Stripe.publishableKey = _stripePublishableKey;
  await Stripe.instance.applySettings();

  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: YouDoApp()));
}
