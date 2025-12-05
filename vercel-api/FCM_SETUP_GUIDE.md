# 🔔 FCM ブラウザ通知セットアップガイド

## 🎯 概要

**FCM (Firebase Cloud Messaging)** を使用したブラウザ通知システムです。

### **通知方式:**
- ✅ **FCM ブラウザ通知** - デスクトップ右下に表示
- ✅ **Firestore リアルタイムリスナー** - アプリ内ダイアログ (フォールバック)

---

## 🔑 必要な環境変数

| 変数名 | 値 | 取得方法 |
|--------|-----|----------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ 設定済み |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ 設定済み |
| `AGORA_APP_CERTIFICATE` | (設定済み) | ✅ 設定済み |
| `FIREBASE_WEB_API_KEY` | `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA` | ❌ **要追加** |

---

## 🚀 セットアップ手順

### **Step 1: FIREBASE_WEB_API_KEY を取得**

**方法 1: Firebase Console から取得 (推奨)**

1. Firebase Console を開く:
   ```
   https://console.firebase.google.com/project/callog-30758/settings/general
   ```

2. **Project settings** (歯車アイコン) → **General** タブ

3. **Your apps** セクション → **Web app** を探す

4. **Web API Key** をコピー:
   ```
   AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA
   ```

**方法 2: Flutter プロジェクトから取得**

`firebase_options.dart`ファイルに既に記載されています:
```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA', // ← これ
  ...
);
```

---

### **Step 2: Vercel 環境変数に追加**

Vercel ダッシュボードを開く:
```
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
```

**追加する環境変数:**

| Key | Value | Environments | Sensitive |
|-----|-------|--------------|-----------|
| `FIREBASE_WEB_API_KEY` | `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA` | ✅ Production, Preview, Development | ❌ Disabled |

**注意:** Web API Key は公開されても問題ありません（クライアント側でも使用されるため）

---

### **Step 3: 再デプロイ**

```bash
cd C:\Users\admin\Downloads\callog-api-v2
vercel --prod
```

---

## 🧪 テスト手順

### **準備: 2つのブラウザ**

**ブラウザ A (発信側):**
```
https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
```
- ユーザー1でログイン

**ブラウザ B (着信側):**
```
https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
```
- ユーザー2でログイン

---

### **Step 1: ブラウザ通知権限を許可**

**ブラウザ B で:**
1. 初回ログイン時にブラウザ通知権限のダイアログが表示される
2. **「許可」**をクリック

```
┌─────────────────────────────────┐
│ 📍 localhost が次の許可を求めて │
│ います:                          │
│                                 │
│ 🔔 通知の送信                   │
│                                 │
│  [ブロック]  [許可] ← クリック   │
└─────────────────────────────────┘
```

---

### **Step 2: ブラウザ B で別のタブを開く**

**重要:** FCM通知の動作を確認するため、Callogタブを**バックグラウンド**にします:

```
[ブラウザ B]
タブ1: YouTube (アクティブ) ← このタブを見る
タブ2: Callog (バックグラウンド)
```

---

### **Step 3: ブラウザ A から通話を発信**

1. ユーザー2を選択
2. 音声通話ボタンをクリック

---

### **Step 4: ブラウザ B でブラウザ通知を確認**

**期待される動作:**

YouTubeタブを見ていても、デスクトップ右下に通知が表示される:

```
┌─────────────────────────────┐
│ 🔔 Callog                   │
│                             │
│ 音声通話着信                 │
│ ユーザー1さんから音声通話が  │
│ かかってきています           │
└─────────────────────────────┘
```

**通知をクリック:**
- Callogタブが前面に表示される
- 着信ダイアログが表示される (Firestoreリスナー経由)

---

## 📊 通知の優先順位

システムは**2段階の通知**を実装しています:

### **1. FCM ブラウザ通知 (優先)**

**動作条件:**
- ✅ アプリがバックグラウンドでも動作
- ✅ 他のタブを見ていても通知
- ✅ ブラウザが最小化されていても通知 (OSによる)

**表示場所:**
- デスクトップ右下 (Windows)
- 画面右上 (Mac)

---

### **2. Firestore リアルタイムリスナー (フォールバック)**

**動作条件:**
- ✅ Callogアプリがアクティブな場合
- ❌ バックグラウンドでは動作しない

**表示場所:**
- Callogアプリ内のダイアログ

---

## 🔧 動作の仕組み

### **発信側 (ブラウザ A):**
```
1. 通話ボタンをクリック
2. Vercel API を呼び出し
   ↓
   POST /api/sendPushNotification
   {
     peerId: "user_id_2",
     channelId: "call_xxx",
     callType: "voice_call",
     callerName: "ユーザー1"
   }
```

### **Vercel API:**
```
1. Firestoreから着信側のFCM Tokenを取得
2. FCM API を呼び出し (Legacy API + Web API Key)
3. Firestoreに call_notifications ドキュメントを作成
```

### **着信側 (ブラウザ B):**
```
1. FCM Service Worker がブラウザ通知を表示
   ↓
   デスクトップ右下に通知
   
2. (オプション) Callogがアクティブな場合
   ↓
   Firestoreリスナーがアプリ内ダイアログを表示
```

---

## 🔍 トラブルシューティング

### **問題 1: ブラウザ通知が表示されない**

**チェックポイント:**
1. ✅ `FIREBASE_WEB_API_KEY` が設定されている
2. ✅ Vercel再デプロイを実行した
3. ✅ ブラウザ通知権限が「許可」になっている
4. ✅ 着信側がログイン済み (FCM Token登録済み)

**ブラウザ通知権限を確認:**
```
ブラウザのアドレスバー → 🔒 アイコン → 「サイトの設定」
→ 通知: 「許可」
```

---

### **問題 2: FCM Token が登録されない**

**解決策:**
1. ログアウト
2. ブラウザをリフレッシュ (`Ctrl + Shift + R`)
3. 再ログイン
4. コンソールログで確認:
   ```
   [Push] ✅ FCM Token acquired: d5A3-3dQg-2wegmmx9CN...
   ```

---

### **問題 3: Legacy API エラー**

**エラーメッセージ:**
```
FCM Legacy API is disabled
```

**原因:**
Firebase ConsoleでLegacy APIが無効化されている

**解決策 A: Legacy API を有効化 (推奨)**
1. Firebase Console → Cloud Messaging
2. **Cloud Messaging API (Legacy)** を有効化

**解決策 B: HTTP v1 API に移行 (複雑)**
- Service Account が必要 (組織ポリシーの制約)

---

## 📋 環境変数の最終確認

| 変数名 | 値 | 状態 |
|--------|-----|------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ |
| `AGORA_APP_CERTIFICATE` | (設定済み) | ✅ |
| `FIREBASE_WEB_API_KEY` | `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA` | ❌ **要追加** |

---

## 🎯 次のステップ

1. **Vercel 環境変数に `FIREBASE_WEB_API_KEY` を追加**
   - URL: https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
   - Value: `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA`

2. **`vercel --prod` で再デプロイ**

3. **2つのブラウザでテスト**
   - ブラウザ A: 通話発信
   - ブラウザ B: 別のタブを開く (YouTube等)
   - ブラウザ通知が表示されることを確認

これで、**バックグラウンドでも着信通知が届く**ようになります! 🔔🚀
