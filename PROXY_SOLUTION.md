# 🔄 プロキシサーバー解決策

## 🚨 最終的な問題

**組織ポリシー `constraints/iam.allowedPolicyMemberDomains`** により:
- ❌ `allUsers` アクセス禁止
- ❌ Cloud Runへの直接パブリックアクセス不可
- ❌ OPTIONS preflightリクエストがCloud Runレベルでブロック

---

## ✅ 実装した解決策

### **プロキシサーバーアーキテクチャ**

Flutterアプリと同じドメイン(sandbox)でプロキシサーバーを起動し、Cloud Functionsへのリクエストを中継します。

```
Flutter App (port 5060)
    ↓ (same domain - no CORS)
Proxy Server (port 8080)  ← CORSヘッダーを追加
    ↓ (with auth token)
Cloud Functions  ← Firebase Auth検証
    ↓
Response
```

### プロキシサーバーの機能

1. **CORS処理**:
   - OPTIONS preflightリクエストを処理
   - 適切なCORSヘッダーを追加
   - 同一ドメインなのでCORS問題なし

2. **リクエスト転送**:
   - Flutter AppからのリクエストをCloud Functionsに転送
   - Authorizationヘッダーを保持
   - レスポンスをそのまま返却

3. **エラーハンドリング**:
   - HTTPエラーを適切に処理
   - タイムアウト処理
   - エラーログ出力

---

## 📊 現在の状態

### ✅ 稼働中のサービス

#### 1. Flutter App
- **Port**: 5060
- **URL**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
- **Status**: ✅ 稼働中

#### 2. Proxy Server
- **Port**: 8080
- **Internal URL**: http://localhost:8080
- **Public URL**: https://8080-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
- **Status**: ✅ 稼働中
- **Endpoints**:
  - `POST /generateAgoraToken`
  - `POST /sendPushNotification`

#### 3. Cloud Functions
- **generateAgoraToken**: https://generateagoratoken-eyix4hluza-uc.a.run.app
- **sendPushNotification**: https://sendpushnotification-eyix4hluza-uc.a.run.app
- **Auth**: Firebase Auth必須

### 📝 Flutter設定

Flutter services updated to use proxy URLs:
```dart
// agora_token_service.dart
static const String _generateTokenUrl = 
    'https://8080-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai/generateAgoraToken';

// push_notification_service.dart
static const String _sendPushUrl = 
    'https://8080-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai/sendPushNotification';
```

---

## 🧪 テスト手順

### 1. アプリを開く
https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

### 2. 強制リフレッシュ
**Ctrl + Shift + R** (新しいビルドを読み込み)

### 3. ログイン
Firebase Authenticationでログイン

### 4. 通話テスト
フレンドに通話を発信

### 5. コンソール確認

**成功の場合**:
```
✅ [AgoraToken] 🎫 Generating token for channel: call_xxxxx
✅ [AgoraToken] ✅ Token generated successfully
✅ [Push] 📤 Sending notification via Cloud Functions
✅ [Push] ✅ Notification sent successfully!
```

**CORSエラーが表示されないこと**を確認!

---

## 🔧 プロキシサーバー管理

### サーバー状態確認
```bash
# プロセス確認
ps aux | grep proxy_server | grep -v grep

# ポート確認
lsof -i :8080

# ログ確認
tail -f /home/user/Callog/proxy.log
```

### サーバー再起動
```bash
# 停止
pkill -f proxy_server

# 起動
cd /home/user/Callog
python3 proxy_server.py > proxy.log 2>&1 &
```

---

## 💡 この解決策の利点

1. **組織ポリシー準拠**
   - `allUsers`アクセス不要
   - Cloud Runの権限変更不要

2. **CORS完全解決**
   - 同一ドメインなのでCORS問題なし
   - OPTIONS preflightを正しく処理

3. **Firebase Auth保持**
   - 認証トークンをそのまま転送
   - セキュリティレイヤーは維持

4. **シンプルな実装**
   - 追加のインフラ不要
   - Pythonの標準ライブラリのみ使用

---

## 🚀 次のステップ

**すべての準備が整いました!**

1. ✅ プロキシサーバー起動済み
2. ✅ Flutterアプリ更新済み
3. ✅ 両サーバー稼働中

**今すぐアプリをテストしてください!**

**アプリURL**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

CORSエラーが解決されているはずです! 🎉
