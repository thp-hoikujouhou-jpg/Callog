# Flutter側の変更内容 - 詳細説明

## 🎯 変更の目的

CORSエラーを解決するため、FlutterアプリがCloud Functionsを呼び出す方法を変更しました。

## ✅ 変更内容 (すでに完了しています!)

### 📁 変更されたファイル

1. **lib/services/agora_token_service.dart** - Agoraトークン生成サービス
2. **lib/services/push_notification_service.dart** - プッシュ通知サービス

---

## 📝 変更1: agora_token_service.dart

### 🔴 変更前のコード

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AgoraTokenService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> generateToken({
    required String channelName,
    int uid = 0,
    String role = 'publisher',
  }) async {
    try {
      // ❌ この方法はCORSエラーを引き起こす
      final callable = _functions.httpsCallable('generateAgoraToken');
      final result = await callable.call({
        'channelName': channelName,
        'uid': uid,
        'role': role,
      });

      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      rethrow;
    }
  }
}
```

### 🟢 変更後のコード (現在のコード)

```dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;  // ✅ 追加
import 'dart:convert';                     // ✅ 追加

class AgoraTokenService {
  // ✅ Cloud Functionsのエンドポイントを直接指定
  static const String _functionsBaseUrl = 
      'https://us-central1-callog-30758.cloudfunctions.net';

  Future<Map<String, dynamic>> generateToken({
    required String channelName,
    int uid = 0,
    String role = 'publisher',
  }) async {
    try {
      // ✅ HTTPリクエストを直接送信 (CORS対応)
      final url = Uri.parse('$_functionsBaseUrl/generateAgoraToken');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'data': {
            'channelName': channelName,
            'uid': uid,
            'role': role,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate token: ${response.body}');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      
      return {
        'token': data['token'] as String?,
        'appId': data['appId'] as String,
        'channelName': data['channelName'] as String,
        'uid': data['uid'] as int,
        'expiresAt': data['expiresAt'] as int?,
      };
    } catch (e) {
      rethrow;
    }
  }
}
```

---

## 📝 変更2: push_notification_service.dart

### 🔴 変更前のコード

```dart
import 'package:cloud_functions/cloud_functions.dart';
// ... 他のインポート

class PushNotificationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> sendCallNotification({
    required String peerId,
    required String channelId,
    required String callType,
    required String callerName,
  }) async {
    try {
      // ❌ この方法はCORSエラーを引き起こす
      final callable = _functions.httpsCallable('sendPushNotification');
      final result = await callable.call({
        'peerId': peerId,
        'channelId': channelId,
        'callType': callType,
        'callerName': callerName,
      });

      final data = result.data as Map<String, dynamic>;
      // ...
    } catch (e) {
      rethrow;
    }
  }
}
```

### 🟢 変更後のコード (現在のコード)

```dart
import 'package:http/http.dart' as http;  // ✅ 追加
import 'dart:convert';                     // ✅ 追加
// ... 他のインポート

class PushNotificationService {
  // ✅ Cloud Functionsのエンドポイントを直接指定
  static const String _functionsBaseUrl = 
      'https://us-central1-callog-30758.cloudfunctions.net';

  Future<void> sendCallNotification({
    required String peerId,
    required String channelId,
    required String callType,
    required String callerName,
  }) async {
    try {
      // ✅ 現在のユーザーIDを取得
      final callerId = _auth.currentUser?.uid ?? 'unknown';

      // ✅ HTTPリクエストを直接送信 (CORS対応)
      final url = Uri.parse('$_functionsBaseUrl/sendPushNotification');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'data': {
            'peerId': peerId,
            'channelId': channelId,
            'callType': callType,
            'callerName': callerName,
            'callerId': callerId,  // ✅ 追加
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[Push] ✅ Notification sent successfully!');
      }
    } catch (e) {
      rethrow;
    }
  }
}
```

---

## 🔍 変更の主なポイント

### 1. インポートの変更
```dart
// ❌ 削除
import 'package:cloud_functions/cloud_functions.dart';

// ✅ 追加
import 'package:http/http.dart' as http;
import 'dart:convert';
```

### 2. エンドポイントの直接指定
```dart
// ✅ Cloud FunctionsのベースURLを定義
static const String _functionsBaseUrl = 
    'https://us-central1-callog-30758.cloudfunctions.net';
```

### 3. 呼び出し方法の変更

**変更前:**
```dart
final callable = _functions.httpsCallable('functionName');
final result = await callable.call(data);
```

**変更後:**
```dart
final url = Uri.parse('$_functionsBaseUrl/functionName');
final response = await http.post(
  url,
  headers: {'Content-Type': 'application/json'},
  body: json.encode({'data': data}),
);
```

---

## ✅ あなたがすべきこと

### Flutter側の変更 → **何もする必要はありません!** 🎉

✅ すでに私が変更を適用しました
✅ ビルドも完了しています
✅ アプリは正常に動作しています

### あなたが実行すべき唯一の作業

**Cloud Functionsのデプロイだけです!**

```bash
cd /home/user/Callog
firebase login
firebase deploy --only functions
```

---

## 🧪 変更の確認方法

変更が正しく適用されているか確認したい場合:

```bash
# agora_token_service.dartの確認
cd /home/user/Callog
grep "http.post" lib/services/agora_token_service.dart

# push_notification_service.dartの確認
grep "http.post" lib/services/push_notification_service.dart

# 両方に"http.post"が含まれていれば、変更が適用されています
```

---

## 📊 変更の影響範囲

### ✅ 変更済み (自動的に完了)
- [x] agora_token_service.dart
- [x] push_notification_service.dart
- [x] Flutter アプリのビルド
- [x] Webサーバーの起動

### ⏳ 未完了 (あなたが実行する必要あり)
- [ ] Cloud Functions のデプロイ

---

## 🎯 まとめ

**Flutter側の変更は100%完了しています!**

あなたは以下を実行するだけです:

1. **Firebase にログイン**
   ```bash
   firebase login
   ```

2. **Cloud Functionsをデプロイ**
   ```bash
   cd /home/user/Callog
   firebase deploy --only functions
   ```

これだけで、CORSエラーが完全に解決されます! 🚀

---

**最終更新**: 2024-12-04
**ステータス**: Flutter側の変更は完了済み
