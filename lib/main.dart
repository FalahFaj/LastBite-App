import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lastbite/firebase_options.dart';
import 'package:lastbite/core/services/notification_service.dart';
import 'package:lastbite/core/router/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lastbite/core/services/local_storage_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await initializeDateFormatting('id_ID', null);

  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();

  await Hive.openBox(LocalStorageService.authBoxName);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notifications
  await NotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    final baseTextTheme = ThemeData.light().textTheme;

    return MaterialApp.router(
      title: 'LastBite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        fontFamily: 'Inter',
        textTheme: baseTextTheme.apply(fontFamily: 'Inter').copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(fontFamily: 'DMSans'),
          displayMedium: baseTextTheme.displayMedium?.copyWith(fontFamily: 'DMSans'),
          displaySmall: baseTextTheme.displaySmall?.copyWith(fontFamily: 'DMSans'),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontFamily: 'DMSans'),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontFamily: 'DMSans'),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontFamily: 'DMSans'),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontFamily: 'DMSans'),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontFamily: 'DMSans'),
          titleSmall: baseTextTheme.titleSmall?.copyWith(fontFamily: 'DMSans'),
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
