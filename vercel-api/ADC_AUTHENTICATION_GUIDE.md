# 🔐 Application Default Credentials (ADC) 認証ガイド

## 📋 概要

**Application Default Credentials (ADC)** は、Service Account Key を使わずに Google Cloud APIs にアクセスする方法です。

---

## 🎯 ADC とは？

ADC は、以下の順序で認証情報を自動的に検索します:

1. **環境変数** `GOOGLE_APPLICATION_CREDENTIALS` (JSON キーファイルパス)
2. **gcloud CLI の認証情報** (`gcloud auth application-default login`)
3. **Cloud Run / GKE の Workload Identity**
4. **Compute Engine のメタデータサーバー**

---

## ✅ 一時的な認証方法 (開発・テスト用)

### Step 1: Google Cloud Shell を開く

Google Cloud Console にアクセス:
```
https://console.cloud.google.com/?project=callog-30758
```

右上の **Cloud Shell アイコン** をクリックして、ターミナルを開きます。

### Step 2: ADC 認証を実行

```bash
# Application Default Credentials を設定
gcloud auth application-default login
```

**プロンプトが表示されます:**
```
Go to the following link in your browser:
    https://accounts.google.com/o/oauth2/auth?...

Enter verification code: 
```

### Step 3: ブラウザで認証

1. 表示された URL をブラウザで開く
2. **あなたの Gmail アカウント** (thp-hoikujouhou@tachanhao.com など) でログイン
3. **Google Cloud Platform への API アクセスを許可**
4. 表示された **認証コード** をコピー
5. Cloud Shell のターミナルに貼り付けて Enter

### Step 4: 認証成功の確認

```bash
# 認証情報が保存されました
Credentials saved to file: 
[/home/thp-hoikujouhou/.config/gcloud/application_default_credentials.json]
```

**これで完了です！** ✅

---

## 🔧 認証情報の確認

```bash
# 現在の認証アカウントを確認
gcloud auth list

# ADC が設定されているか確認
gcloud auth application-default print-access-token
```

**出力例:**
```
ya29.a0AfB_byC... (アクセストークン)
```

---

## 🧪 Node.js でのテスト

### 認証なしのコード (ADC を使用)

```javascript
// sendPushNotification.js (ADC 対応)
const admin = require('firebase-admin');

// ADC を使用して自動認証
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'callog-30758',
    // credential は指定しない → ADC が自動的に使用される
  });
}

const db = admin.firestore();

// 以降、通常通りに使用可能
const usersRef = db.collection('users');
const snapshot = await usersRef.get();
```

### ローカルでテスト

```bash
# 1. ADC 認証を実行
gcloud auth application-default login

# 2. Node.js スクリプトを実行
cd /path/to/callog-api-v2
node test-firestore.js
```

**出力例:**
```
✅ Firestore connected successfully
📄 Found 5 users in database
```

---

## 🌐 Vercel でも使えるか？

**答え: いいえ ❌**

ADC は以下の環境でのみ動作します:

✅ **ローカル開発環境** (gcloud CLI がインストールされている)
✅ **Google Cloud Shell**
✅ **Cloud Run** (Workload Identity)
✅ **Compute Engine / GKE**

❌ **Vercel** (サードパーティホスティング)
❌ **Netlify**
❌ **AWS Lambda**

---

## 🎯 各環境での認証方法まとめ

| 環境 | 認証方法 | 秘密鍵 | 推奨度 |
|------|---------|-------|--------|
| **ローカル開発** | ADC (`gcloud auth application-default login`) | 不要 ✅ | ✅ 推奨 |
| **Google Cloud Shell** | ADC (自動) | 不要 ✅ | ✅ 推奨 |
| **Cloud Run** | Workload Identity | 不要 ✅ | ✅ 最も安全 |
| **Vercel** | Web API Key または Service Account Key | Web API Key: 不要 ✅ | ✅ 現在使用中 |

---

## 🔧 実際のコマンド例

### ローカル開発でのワークフロー

```bash
# 1. Google Cloud プロジェクトを設定
gcloud config set project callog-30758

# 2. ADC 認証
gcloud auth application-default login

# 3. Node.js プロジェクトに移動
cd ~/callog-api-v2

# 4. 依存関係をインストール
npm install

# 5. ローカルサーバーを起動
node server.js

# 6. 別のターミナルでテスト
curl -X POST http://localhost:8080/api/sendPushNotification \
  -H "Content-Type: application/json" \
  -d '{"data":{"fcmToken":"test123","callType":"voice_call","callerName":"Test","channelId":"ch1"}}'
```

---

## ⚠️ 本番環境での注意点

### ❌ 本番環境で ADC (個人アカウント) を使用しない

**理由:**
- 個人の Gmail アカウントに依存
- アクセストークンが有効期限切れになる
- セキュリティリスク
- 他の人がアクセスできない

### ✅ 本番環境での推奨方法

**Option 1: Cloud Run + Workload Identity**
```bash
# Cloud Run にデプロイすると自動的に Workload Identity が使用される
gcloud run deploy callog-api \
  --source . \
  --service-account callog-api-sa@callog-30758.iam.gserviceaccount.com
```

**Option 2: Vercel + Web API Key (現在の実装)**
```javascript
// FCM Legacy API with Web API Key
Authorization: key=AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA
```

---

## 🧪 ADC を使ったテストスクリプト

### test-firestore.js

```javascript
// test-firestore.js
const admin = require('firebase-admin');

// ADC を使用 (認証情報の指定なし)
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'callog-30758',
  });
}

const db = admin.firestore();

async function testFirestore() {
  try {
    console.log('🔍 Testing Firestore connection with ADC...');
    
    // ユーザー一覧を取得
    const usersRef = db.collection('users');
    const snapshot = await usersRef.limit(5).get();
    
    console.log(`✅ Firestore connected successfully`);
    console.log(`📄 Found ${snapshot.size} users`);
    
    snapshot.forEach(doc => {
      console.log(`   - User ID: ${doc.id}`);
    });
    
  } catch (error) {
    console.error('❌ Firestore connection failed:', error);
  }
}

testFirestore();
```

### 実行方法

```bash
# 1. ADC 認証
gcloud auth application-default login

# 2. テストスクリプトを実行
cd ~/callog-api-v2
node test-firestore.js
```

**期待される出力:**
```
🔍 Testing Firestore connection with ADC...
✅ Firestore connected successfully
📄 Found 5 users
   - User ID: eU1lNB3Q5dhcd7ysLWq2fNvze1l2
   - User ID: abc123def456
   ...
```

---

## 📋 トラブルシューティング

### Error: "Could not load the default credentials"

**原因:** ADC が設定されていない

**解決策:**
```bash
gcloud auth application-default login
```

### Error: "Permission denied"

**原因:** あなたの Gmail アカウントに Firestore へのアクセス権限がない

**解決策:**

1. Firebase Console で権限を付与:
   `https://console.firebase.google.com/project/callog-30758/settings/iam`

2. あなたのアカウント (thp-hoikujouhou@tachanhao.com) に以下のロールを追加:
   - **Firebase Admin**
   - **Cloud Datastore User**

### Error: "ADC not found"

**原因:** gcloud CLI がインストールされていない

**解決策:**
- Google Cloud Shell を使用する (推奨)
- または gcloud CLI をインストール: `https://cloud.google.com/sdk/docs/install`

---

## 🎯 まとめ

### ADC の使い分け

| 用途 | ADC | Service Account Key |
|------|-----|---------------------|
| **ローカル開発** | ✅ 推奨 | ⚠️ 可能だが非推奨 |
| **Google Cloud Shell** | ✅ 推奨 | ⚠️ 可能だが非推奨 |
| **Cloud Run (本番)** | ✅ Workload Identity | ❌ 非推奨 |
| **Vercel (本番)** | ❌ 使用不可 | ⚠️ または Web API Key |

### 推奨事項

**開発・テスト:**
```bash
gcloud auth application-default login
```
✅ 一時的に使える
✅ JSON キーファイル不要
✅ 簡単

**本番環境:**
- **Vercel**: Web API Key (現在の実装) ✅
- **Cloud Run**: Workload Identity ✅

---

## 🚀 次のステップ

### ローカルでテストしたい場合

1. Google Cloud Shell を開く
2. `gcloud auth application-default login` を実行
3. `test-firestore.js` を実行
4. 動作を確認

### Vercel で本番運用したい場合

1. 現在の実装 (Web API Key) を使用
2. ダウンロード: `https://www.genspark.ai/api/files/s/tlJ3yFkA`
3. Vercel にデプロイ
4. テスト

どちらを試しますか？ 🎯
