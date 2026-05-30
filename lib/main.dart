// lib/main.dart
// ═══════════════════════════════════════════════════════════════════════════
// FIX SUMMARY (Memory / Listener Leak):
//
// BUG: _showLocalNotification() contained two stream subscriptions:
//
//   FirebaseMessaging.onMessage.listen((_) {});           // ← new sub every call
//   FirebaseMessaging.instance.onTokenRefresh.listen((_) {}); // ← same
//
//   These are called EVERY TIME a foreground notification arrives, creating a
//   new dangling StreamSubscription each time. After N notifications you have N
//   leaked subscriptions consuming memory and CPU for the lifetime of the app.
//
// FIX: Remove the two rogue listen() calls from _showLocalNotification().
//   Both streams are already subscribed in _setupFCM() which runs once at
//   startup — so nothing is lost.  If you need to handle token-refresh (e.g.
//   to push the new token to Supabase), wire it up once in _setupFCM().
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';

// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 40),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize local notifications
  await _initLocalNotifications();

  // Request FCM permissions + wire up streams ONCE
  await _setupFCM();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LendingApp(),
    ),
  );
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS:     iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Create high-importance Android channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'lending_high_importance',
    'Lending Notifications',
    description: 'Jireta Loans & Credit Corp. notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert:       true,
    badge:       true,
    sound:       true,
    provisional: false,
  );

  // Foreground messages — subscribed ONCE here, nowhere else.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showLocalNotification(message);
  });

  // App opened from notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // Navigate based on message data if needed.
  });

  // Token refresh — subscribed ONCE here.
  // Store the new token in Supabase users table when it rotates.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    final supabase = Supabase.instance.client;
    final authId   = supabase.auth.currentUser?.id;
    if (authId == null) return;
    supabase
        .from('users')
        .update({'fcm_token': newToken})
        .eq('auth_id', authId)
        .then((_) {})
        .catchError((_) {}); // silent — non-critical
  });
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  const NotificationDetails notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'lending_high_importance',
      'Lending Notifications',
      channelDescription: 'Jireta Loans & Credit Corp. notifications',
      importance: Importance.high,
      priority:   Priority.high,
      icon:       '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    notificationDetails,
  );

  // FIX ─ Removed two leaked stream subscriptions that were here in the
  //        original.  _setupFCM() already subscribes both streams once at
  //        startup, so these extra listen() calls were pure leaks.
}

// ============================================================
// DefaultFirebaseOptions — Replace with your firebase_options.dart values
// ============================================================
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Replace these with your actual Firebase project config.
    // Run: flutterfire configure
    return const FirebaseOptions(
      apiKey:            'YOUR_FIREBASE_API_KEY',
      appId:             'YOUR_FIREBASE_APP_ID',
      messagingSenderId: 'YOUR_SENDER_ID',
      projectId:         'YOUR_PROJECT_ID',
      storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    );
  }
}

// ============================================================
// Root App Widget
// ============================================================
class LendingApp extends ConsumerWidget {
  const LendingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title:                    'Jireta Loans & Credit Corp.',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.lightTheme,
      darkTheme:  AppTheme.darkTheme,
      themeMode:  themeMode,
      routerConfig: router,
    );
  }
}