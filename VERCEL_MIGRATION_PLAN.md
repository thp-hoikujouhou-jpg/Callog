# 🚀 Vercel Functions 移行計画

## ✅ 正しい理解です！

### **移行するもの**
- ❌ Cloud Functions (`generateAgoraToken`, `sendPushNotification`) → **削除**
- ✅ → Vercel Functions に移行

### **そのまま使い続けるもの**
- ✅ Firebase Authentication (認証)
- ✅ Firebase Firestore (データベース)
- ✅ Firebase Storage (ファイルストレージ)
- ✅ Firebase Cloud Messaging (プッシュ通知)
- ✅ Flutterアプリ (変更最小限)

---

## 📋 移行手順

### **Phase 1: Vercel Functions 作成 (15分)**

#### 1. ローカルでプロジェクト作成
```bash
cd /home/user
mkdir callog-api
cd callog-api

# package.json 作成
npm init -y

# 必要なパッケージをインストール
npm install firebase-admin agora-token
```

#### 2. API関数を作成

**`api/generateAgoraToken.js`** (Agora Token生成):
```javascript
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

// Firebase Admin初期化 (1回のみ)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
}

export default async function handler(req, res) {
  // CORS設定
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // OPTIONS preflight処理
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    console.log('🎫 Generating Agora token:', req.body);
    
    // 認証チェック (オプション)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const idToken = authHeader.split('Bearer ')[1];
      try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log('✅ Authenticated user:', decodedToken.uid);
      } catch (authError) {
        console.warn('⚠️ Auth verification failed:', authError.message);
      }
    }
    
    // リクエストデータ取得
    const data = req.body.data || req.body;
    const { channelName, uid = 0, role = 'publisher' } = data;
    
    if (!channelName) {
      return res.status(400).json({
        error: 'Channel name is required'
      });
    }
    
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    
    // App Certificate未設定の場合
    if (!appCertificate) {
      console.warn('⚠️ App Certificate not configured');
      return res.status(200).json({
        data: {
          token: null,
          appId,
          channelName,
          uid,
          message: 'Token generation disabled - App Certificate not configured',
        }
      });
    }
    
    // Agoraトークン生成
    const expirationTimeInSeconds = Math.floor(Date.now() / 1000) + 86400; // 24時間
    const rtcRole = role === 'audience' ? RtcRole.AUDIENCE : RtcRole.PUBLISHER;
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      rtcRole,
      expirationTimeInSeconds
    );
    
    console.log('✅ Token generated successfully');
    
    return res.status(200).json({
      data: {
        token,
        appId,
        channelName,
        uid,
        expiresAt: expirationTimeInSeconds,
      }
    });
    
  } catch (error) {
    console.error('❌ Error generating Agora token:', error);
    return res.status(500).json({
      error: 'Failed to generate Agora token: ' + error.message
    });
  }
}
```

**`api/sendPushNotification.js`** (プッシュ通知送信):
```javascript
const admin = require('firebase-admin');

// Firebase Admin初期化 (共通)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
}

export default async function handler(req, res) {
  // CORS設定
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    console.log('📲 Sending push notification:', req.body);
    
    // 認証チェック
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const idToken = authHeader.split('Bearer ')[1];
      try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        console.log('✅ Authenticated user:', decodedToken.uid);
      } catch (authError) {
        console.warn('⚠️ Auth verification failed:', authError.message);
      }
    }
    
    // リクエストデータ
    const data = req.body.data || req.body;
    const { peerId, channelId, callType, callerName, callerId } = data;
    
    if (!peerId || !channelId || !callType || !callerName) {
      return res.status(400).json({
        error: 'Missing required parameters'
      });
    }
    
    // FirestoreからFCMトークン取得
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(peerId)
      .get();
    
    if (!userDoc.exists) {
      throw new Error('User not found');
    }
    
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) {
      throw new Error('FCM token not found for user');
    }
    
    // FCMメッセージ作成
    const message = {
      token: fcmToken,
      notification: {
        title: callType === 'video_call' ? '📹 ビデオ通話' : '📞 音声通話',
        body: `${callerName}さんから着信`,
      },
      data: {
        type: 'incoming_call',
        channelId,
        callType,
        callerId: callerId || 'unknown',
        callerName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'call_notifications',
          priority: 'high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      webpush: {
        notification: {
          icon: '/icon.png',
          badge: '/badge.png',
          vibrate: [200, 100, 200],
        },
      },
    };
    
    // FCMメッセージ送信
    const response = await admin.messaging().send(message);
    console.log('✅ Push notification sent:', response);
    
    // Firestoreに通知記録を保存
    await admin.firestore()
      .collection('call_notifications')
      .add({
        callerId: callerId || 'unknown',
        peerId,
        channelId,
        callType,
        callerName,
        status: 'sent',
        fcmResponse: response,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    return res.status(200).json({
      data: {
        success: true,
        messageId: response,
      }
    });
    
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    return res.status(500).json({
      error: 'Failed to send push notification: ' + error.message
    });
  }
}
```

#### 3. vercel.json 作成
```json
{
  "version": 2,
  "builds": [
    {
      "src": "api/**/*.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "/api/$1"
    }
  ]
}
```

---

### **Phase 2: Vercelにデプロイ (10分)**

#### 1. Vercel CLIインストール
```bash
npm install -g vercel
```

#### 2. Vercelにログイン
```bash
vercel login
```

#### 3. デプロイ
```bash
cd /home/user/callog-api
vercel

# プロジェクト名: callog-api
# 自動検出されるので Enter押すだけ
```

#### 4. 環境変数を設定
Vercel Dashboard → Project Settings → Environment Variables:

- `FIREBASE_PROJECT_ID`: `callog-30758`
- `FIREBASE_CLIENT_EMAIL`: (Firebase Admin SDKのclient_email)
- `FIREBASE_PRIVATE_KEY`: (Firebase Admin SDKのprivate_key)
- `AGORA_APP_ID`: `d1a8161eb70448d89eea1722bc169c92`
- `AGORA_APP_CERTIFICATE`: (Agora Consoleから取得)

#### 5. 本番デプロイ
```bash
vercel --prod
# → https://callog-api.vercel.app
```

---

### **Phase 3: Flutter アプリ更新 (5分)**

#### 1. API URLを更新

**`lib/services/agora_token_service.dart`**:
```dart
static const String _generateTokenUrl = 
    'https://callog-api.vercel.app/api/generateAgoraToken';
```

**`lib/services/push_notification_service.dart`**:
```dart
static const String _sendPushUrl = 
    'https://callog-api.vercel.app/api/sendPushNotification';
```

#### 2. リビルド
```bash
cd /home/user/Callog
flutter build web --release
```

#### 3. サーバー再起動
```bash
lsof -ti:5060 | xargs -r kill -9
cd /home/user/Callog
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 > /home/user/server.log 2>&1 &
```

---

### **Phase 4: Cloud Functions削除 (5分)**

#### Vercelが正常動作確認後に削除:

```bash
cd /home/user/Callog
firebase functions:delete generateAgoraToken --region us-central1 --force
firebase functions:delete sendPushNotification --region us-central1 --force
firebase functions:delete cleanupOldNotifications --region us-central1 --force
```

---

## 📊 移行前後の比較

### **移行前 (現在)**
```
Flutter App
    ↓ 🚫 組織ポリシーでブロック
Firebase Cloud Functions
    ├─→ Firestore ✅
    ├─→ Firebase Auth ✅
    └─→ Agora ❌
```

### **移行後**
```
Flutter App
    ↓ ✅ 完全動作
Vercel Functions (APIサーバー)
    ├─→ Firestore ✅ (そのまま使用)
    ├─→ Firebase Auth ✅ (そのまま使用)
    ├─→ Firebase Storage ✅ (そのまま使用)
    ├─→ FCM ✅ (そのまま使用)
    └─→ Agora ✅ (完全動作)
```

---

## 💰 コスト比較

| | Firebase Cloud Functions | Vercel Functions |
|---|---|---|
| **月間リクエスト** | 200万まで無料 | 100万まで無料 |
| **実行時間** | 40万GB秒まで無料 | 100GB時間まで無料 |
| **組織ポリシー** | ❌ 影響受ける | ✅ 影響なし |
| **CORS問題** | ❌ あり | ✅ なし |
| **推奨** | - | ⭐⭐⭐⭐⭐ |

**結論**: Vercel Functionsの方が問題なく動作する

---

## ✅ チェックリスト

### 移行前
- [ ] Firebase Admin SDK JSONを準備
- [ ] Agora App IDとCertificateを確認
- [ ] Vercelアカウント作成

### 移行中
- [ ] `/home/user/callog-api` プロジェクト作成
- [ ] `api/generateAgoraToken.js` 作成
- [ ] `api/sendPushNotification.js` 作成
- [ ] `vercel.json` 作成
- [ ] Vercelにデプロイ
- [ ] 環境変数設定
- [ ] テスト実行

### 移行後
- [ ] Flutterアプリ更新
- [ ] リビルド＆再起動
- [ ] 動作確認
- [ ] Cloud Functions削除
- [ ] プロキシサーバー停止 (不要になる)

---

## 🎯 期待される結果

### ✅ 動作するもの
- Agora Token生成
- プッシュ通知送信
- Firebase Auth認証
- Firestore読み書き
- Firebase Storage
- **CORSエラーなし**
- **組織ポリシーの影響なし**

### ❌ 削除されるもの
- Firebase Cloud Functions (generateAgoraToken, sendPushNotification)
- プロキシサーバー (不要になる)

---

**次のステップ**: Vercelアカウントを作成して、移行を開始しますか？🚀
