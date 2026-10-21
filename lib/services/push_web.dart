import 'dart:js_interop';

@JS('royalPushSubscribe')
external JSPromise<JSString> _subscribe(JSString publicKey);

@JS('royalPushExistingSubscription')
external JSPromise<JSString> _existingSubscription();

@JS('royalPushUnsubscribe')
external JSPromise<JSAny?> _unsubscribe();

class WebPushBridge {
  static Future<String?> subscribe(String publicKey) async =>
      (await _subscribe(publicKey.toJS).toDart).toDart;

  static Future<String?> existingSubscription() async =>
      (await _existingSubscription().toDart).toDart;

  static Future<void> unsubscribe() async {
    await _unsubscribe().toDart;
  }
}
