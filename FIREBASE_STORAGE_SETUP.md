# 🔥 Firebase Storage CORS問題の完全解決ガイド

## 🚨 問題
```
Access to XMLHttpRequest at 'https://firebasestorage.googleapis.com/...'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header
```

## 🔍 根本原因

1. **Uniform Bucket-Level Access が有効** → 個別ACL設定不可
2. **CORS設定がない** → クロスオリジンリクエストが拒否される
3. **Storage Rules は CORS を制御しない** → 別途設定が必要

---

## ✅ 解決策 (3つの方法)

### 方法1: Google Cloud Console で CORS 設定 (推奨・最も簡単)

1. **Google Cloud Console** を開く:
   https://console.cloud.google.com/storage/browser?project=callog-30758

2. バケット `callog-30758.firebasestorage.app` をクリック

3. 上部の **「構成」** タブをクリック

4. **「CORS」** セクションを見つける

5. **「編集」** をクリック

6. 以下のJSON設定を追加:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Authorization"],
    "maxAgeSeconds": 3600
  }
]
```

7. **「保存」** をクリック

✅ **完了!** これでCORS問題が解決します。

---

### 方法2: gcloud CLI を使用 (ターミナル経由)

```bash
# 1. Google Cloud SDK がインストールされているか確認
gcloud --version

# 2. 認証
gcloud auth login

# 3. プロジェクトを設定
gcloud config set project callog-30758

# 4. CORS設定を適用
gcloud storage buckets update gs://callog-30758.firebasestorage.app --cors-file=firebase_storage_cors.json
```

---

### 方法3: Firebase Storage Rules を完全公開に (一時的)

**注意:** この方法はセキュリティ上推奨されませんが、開発/テスト用として使用できます。

Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_images/{userId}/{allPaths=**} {
      allow read: if true;  // ✅ 完全公開
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**しかし、これだけではCORS問題は解決しません!** 方法1または2も必要です。

---

## 🧪 テスト方法

CORS設定適用後:

1. ブラウザの**すべてのキャッシュをクリア** (Ctrl+Shift+Delete)
2. アプリをリロード
3. カレンダー → 2025/12/10 → park_saeroyi をタップ
4. **✅ 期待される結果:** プロフィール画像が正しく表示される

---

## 🔍 CORS設定の確認方法

ターミナルで確認:

```bash
curl -I https://firebasestorage.googleapis.com/v0/b/callog-30758.firebasestorage.app/o/profile_images%2FeU1lNB3Q5dhcd7ysLWq2fNvze1l2%2F1764376157137.jpg?alt=media
```

**成功した場合、以下のヘッダーが表示されます:**
```
Access-Control-Allow-Origin: *
```

---

## 💡 推奨アプローチ

**開発環境:**
- 方法1 (Google Cloud Console) でCORS設定
- Storage Rulesで`allow read: if true`

**本番環境:**
- CORS設定は同じ
- Storage Rulesで`allow read: if request.auth != null`

---

## 📞 サポート

問題が解決しない場合:
1. ブラウザのコンソールログを確認
2. Network タブで画像リクエストのヘッダーを確認
3. CORS設定が正しく適用されているか確認

---

**一緒に解決しましょう!** 💪✨
