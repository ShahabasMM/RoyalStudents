import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigation.dart';
import 'push_web_stub.dart'
    if (dart.library.js_interop) 'push_web.dart' as web_push;

class WebPushNotificationsService {
  WebPushNotificationsService._();

  // The public key is fetched from the authenticated Supabase Edge Function at
  // runtime. That avoids a silent, blank key when Vercel's Flutter build omits
  // a dart-define. The private key never leaves Supabase.
  static bool get isConfigured => kIsWeb;

  /// Sync only an already-granted browser subscription; never request
  /// notification permission automatically during app startup.
  static Future<void> initializeForSignedInStudent() async {
    if (!isConfigured || Supabase.instance.client.auth.currentUser == null) {
      return;
    }
    try {
      final serialized = await web_push.WebPushBridge.existingSubscription();
      if (serialized != null && serialized.isNotEmpty) {
        await _saveSubscription(serialized);
      }
    } catch (error) {
      debugPrint('WEB PUSH SYNC UNAVAILABLE: $error');
    }
  }

  /// Call only from a user gesture (the Enable notifications menu action).
  static Future<bool> enableForSignedInStudent() async {
    if (!isConfigured) return false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final config = await Supabase.instance.client.functions.invoke(
        'send-student-web-push',
        body: {'event': 'push.config'},
      );
      final publicVapidKey = (config.data as Map?)?['publicVapidKey'] as String?;
      if (config.status != 200 || publicVapidKey == null || publicVapidKey.isEmpty) {
        throw StateError('Push setup is incomplete on the server.');
      }

      final serialized = await web_push.WebPushBridge.subscribe(publicVapidKey);
      if (serialized == null || serialized.isEmpty) return false;
      await _saveSubscription(serialized);
      return true;
    } catch (error) {
      debugPrint('WEB PUSH SUBSCRIBE ERROR: $error');
      final message = error.toString().replaceFirst('Exception: ', '');
      appScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
  }

  static Future<void> _saveSubscription(String serialized) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final subscription = jsonDecode(serialized) as Map<String, dynamic>;
    final keys = subscription['keys'] as Map<String, dynamic>?;
    final endpoint = subscription['endpoint'] as String?;
    final p256dh = keys?['p256dh'] as String?;
    final authSecret = keys?['auth'] as String?;
    if (endpoint == null || p256dh == null || authSecret == null) {
      throw const FormatException('Browser returned an incomplete push subscription.');
    }

    await Supabase.instance.client.from('student_web_push_subscriptions').upsert(
      {
        'auth_user_id': user.id,
        'endpoint': endpoint,
        'p256dh': p256dh,
        'auth_secret': authSecret,
        'expiration_time': subscription['expirationTime'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'auth_user_id,endpoint',
    );
  }

  static Future<void> unregisterCurrentSubscription() async {
    if (!kIsWeb) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final serialized = await web_push.WebPushBridge.existingSubscription();
      if (serialized != null && serialized.isNotEmpty) {
        final subscription = jsonDecode(serialized) as Map<String, dynamic>;
        final endpoint = subscription['endpoint'] as String?;
        if (endpoint != null) {
          await Supabase.instance.client
              .from('student_web_push_subscriptions')
              .delete()
              .eq('auth_user_id', user.id)
              .eq('endpoint', endpoint);
        }
      }
      await web_push.WebPushBridge.unsubscribe();
    } catch (error) {
      debugPrint('WEB PUSH UNSUBSCRIBE ERROR: $error');
    }
  }
}
