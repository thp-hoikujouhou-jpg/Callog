# 🔐 Workload Identity for Callog API

## ⚠️ Important Note

**Workload Identity は Google Cloud Platform (GCP) でのみ動作します。**

Vercel (サードパーティホスティング) では使用できません。

---

## 📋 Workload Identity とは？

Workload Identity は、Google Cloud 上で動作するアプリケーションが、**秘密鍵なし**でGoogle Service APIs にアクセスできる仕組みです。

### 仕組み

```
Cloud Run / GKE Pod
    ↓ (Workload Identity enabled)
Google Service Account (自動バインド)
    ↓ (Application Default Credentials)
Firestore / Firebase APIs
```

### 利点

✅ **秘密鍵不要**
✅ **自動的に認証**
✅ **より安全**
✅ **Google Cloud ネイティブ**

### 制限

❌ **Google Cloud Platform でのみ動作**
❌ **Vercel, Netlify, AWS Lambda では使用不可**
❌ **Cloud Run または GKE が必要**

---

## 🚀 Cloud Run への移行手順 (Workload Identity 使用)

### Step 1: プロジェクト構造の準備

```
callog-api-v2/
├── api/
│   ├── generateAgoraToken.js
│   └── sendPushNotification.js
├── Dockerfile              # ← 追加
├── package.json
└── .gcloudignore           # ← 追加
```

### Step 2: Dockerfile 作成

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY . .

# Expose port 8080 (Cloud Run default)
EXPOSE 8080

# Start server
CMD ["node", "server.js"]
```

### Step 3: Express サーバー作成

```javascript
// server.js
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(express.json());

// CORS
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  next();
});

// Import API handlers
const generateAgoraToken = require('./api/generateAgoraToken');
const sendPushNotification = require('./api/sendPushNotification');

// Routes
app.post('/api/generateAgoraToken', generateAgoraToken);
app.post('/api/sendPushNotification', sendPushNotification);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'Callog API' });
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

### Step 4: sendPushNotification.js (Workload Identity 対応)

```javascript
// api/sendPushNotification.js (Workload Identity version)
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with Application Default Credentials
// Workload Identity will automatically provide credentials
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'callog-30758',
    // No credential needed - Workload Identity provides it automatically
  });
}

const db = admin.firestore();

module.exports = async (req, res) => {
  try {
    const data = req.body?.data || req.body;
    const { fcmToken, callType, callerName, channelId, callerId, peerId } = data;
    
    if (!fcmToken) {
      return res.status(400).json({ error: 'Missing fcmToken' });
    }

    console.log(`📤 Sending FCM notification via Workload Identity`);

    // Send FCM notification using Firebase Admin SDK
    const message = {
      token: fcmToken,
      notification: {
        title: `🔔 ${callType === 'voice_call' ? '音声' : 'ビデオ'}通話着信`,
        body: `${callerName}さんから${callType === 'voice_call' ? '音声' : 'ビデオ'}通話がかかってきています`,
      },
      data: {
        type: callType,
        channelId: channelId,
        callerName: callerName,
        callerId: callerId || 'unknown',
        peerId: peerId || 'unknown',
        timestamp: Date.now().toString(),
      },
      webpush: {
        fcmOptions: {
          link: 'https://callog-api-xxxxxxxxx.a.run.app',
        },
        notification: {
          icon: '/icon.png',
          badge: '/badge.png',
          tag: `call_${channelId}`,
          requireInteraction: true,
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log(`✅ FCM notification sent: ${response}`);

    return res.status(200).json({
      data: {
        success: true,
        messageId: response,
        message: 'Push notification sent via Firebase Admin SDK (Workload Identity)',
        method: 'FCM HTTP v1 API',
      }
    });

  } catch (error) {
    console.error('❌ Error:', error);
    return res.status(500).json({
      error: 'Failed to send notification',
      message: error.message
    });
  }
};
```

### Step 5: package.json 更新

```json
{
  "name": "callog-api",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "firebase-admin": "^12.0.0",
    "agora-token": "^2.0.3"
  },
  "scripts": {
    "start": "node server.js"
  }
}
```

### Step 6: Cloud Run にデプロイ

```bash
# 1. Google Cloud プロジェクトを設定
gcloud config set project callog-30758

# 2. Cloud Run サービスを作成してデプロイ
gcloud run deploy callog-api \
  --source . \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=callog-30758,AGORA_APP_ID=d1a8161eb70448d89eea1722bc169c92 \
  --service-account callog-api-sa@callog-30758.iam.gserviceaccount.com
```

### Step 7: Workload Identity を有効化

```bash
# 1. サービスアカウントを作成
gcloud iam service-accounts create callog-api-sa \
  --display-name "Callog API Service Account"

# 2. Firebase Admin SDK 権限を付与
gcloud projects add-iam-policy-binding callog-30758 \
  --member serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com \
  --role roles/firebase.admin

# 3. Firestore 権限を付与
gcloud projects add-iam-policy-binding callog-30758 \
  --member serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com \
  --role roles/datastore.user

# 4. Cloud Run サービスとサービスアカウントをバインド
gcloud run services update callog-api \
  --service-account callog-api-sa@callog-30758.iam.gserviceaccount.com \
  --region asia-northeast1
```

---

## 📊 コスト比較

| プラットフォーム | 無料枠 | 課金開始 | 月額コスト (予想) |
|----------------|--------|---------|------------------|
| **Vercel** | 100GB 帯域 | 超過後 | $0-20 |
| **Cloud Run** | 200万リクエスト/月 | 超過後 | $0-10 |

Cloud Run の無料枠は **200万リクエスト/月** なので、小規模アプリなら無料で運用可能です。

---

## ⚠️ 移行のデメリット

❌ **Vercel より設定が複雑**
❌ **Google Cloud の知識が必要**
❌ **デプロイ時間が長い**
❌ **Vercel の便利機能が使えない** (Preview Deployments など)

---

## ✅ 移行のメリット

✅ **Workload Identity で秘密鍵不要**
✅ **Firebase Admin SDK が使える**
✅ **FCM HTTP v1 API が使える** (Legacy API より新しい)
✅ **Google Cloud ネイティブ**
✅ **より安全**

---

## 🎯 推奨事項

### 現状のままで良い場合

✅ **Vercel + Web API Key (現在の実装)** を使用
- 簡単にデプロイ可能
- 秘密鍵不要
- すぐに動作

### より安全にしたい場合

✅ **Cloud Run + Workload Identity** に移行
- 秘密鍵不要
- Google Cloud ネイティブ
- Firebase Admin SDK が使える

---

## 📋 まとめ

| 認証方式 | 使用可能な場所 | 秘密鍵 | 推奨度 |
|---------|--------------|-------|--------|
| **Service Account Key** | どこでも | 必要 ❌ | ⚠️ 非推奨 |
| **Web API Key** | どこでも | 不要 ✅ | ✅ Vercel で使用中 |
| **Workload Identity** | Google Cloud のみ | 不要 ✅ | ✅ 最も安全 |

---

## 🚀 次のステップ

### Option 1: 現状のまま (推奨)

✅ Vercel + Web API Key を使用
✅ 既に動作している
✅ すぐにテスト可能

### Option 2: Cloud Run に移行

✅ Workload Identity を使用
✅ より安全
✅ 設定が必要

---

どちらを選びますか？

1. **現状のまま (Vercel + Web API Key)** - すぐ使える ✅
2. **Cloud Run に移行 (Workload Identity)** - より安全だが設定が必要

ご希望をお聞かせください！ 🎯
