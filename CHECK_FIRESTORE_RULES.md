# 🔥 Firestore Security Rules チェックガイド

## 🚨 問題: 通話履歴が取得できない

### 症状
- カレンダー → 日付選択 → 「この日は通話がありません」
- park_saeroyiの丸写真が表示されない
- 連絡先グリッドが空

### 原因
`call_recordings`コレクションのクエリが失敗している可能性が高い

---

## ✅ 必要なFirestore Security Rules

Firebase Console → Firestore Database → Rules で以下を確認してください:

### 現在のルール (推測)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Call recordings - ❌ 問題の可能性あり
    match /call_recordings/{recordingId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
    
    // Sticky notes
    match /sticky_notes/{noteId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

---

## 🔧 推奨される修正ルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ Users collection
    match /users/{userId} {
      allow read: if request.auth != null;  // すべての認証済みユーザーが読み取り可能
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ✅ Call recordings - FIXED!
    match /call_recordings/{recordingId} {
      // 重要: クエリ時にresource.dataにアクセスできない!
      // where('userId', isEqualTo: user.uid) のクエリを許可する必要がある
      allow read: if request.auth != null;  // ← これに変更!
      allow write: if request.auth != null;
    }
    
    // ✅ Sticky notes
    match /sticky_notes/{noteId} {
      allow read: if request.auth != null;  // クエリを許可
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // ✅ Contacts collection (もし使用している場合)
    match /contacts/{contactId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // ✅ FCM tokens
    match /fcm_tokens/{tokenId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## 🔍 重要な理解: なぜ変更が必要か?

### 問題のあるルール
```javascript
allow read: if request.auth != null && request.auth.uid == resource.data.userId;
```

**このルールの問題点:**
- `resource.data` は**個別ドキュメント取得時のみ**利用可能
- **クエリ (where句) の場合はアクセスできない**
- 結果: すべてのクエリが失敗する

### 正しいルール
```javascript
allow read: if request.auth != null;
```

**このルールの利点:**
- クエリが許可される
- アプリ側で `where('userId', isEqualTo: user.uid)` でフィルタリング
- 他のユーザーのデータは取得されない (クエリでフィルタ済み)

---

## 📋 設定手順

### ステップ1: Firebase Console を開く
https://console.firebase.google.com/

### ステップ2: プロジェクトを選択
**callog-30758**

### ステップ3: Firestore Database → Rules
左メニュー → **Firestore Database** → 上部タブ **Rules**

### ステップ4: ルールを更新
上記の**推奨される修正ルール**をコピー&ペースト

### ステップ5: 公開
**「公開」**ボタンをクリック

---

## 🧪 テスト方法

ルール更新後:

1. **ブラウザをリロード** (Ctrl+R)
2. **F12でコンソールを開く**
3. **カレンダー → 2025/12/10**
4. **コンソールログを確認:**

**成功した場合:**
```
📱 [DailyContacts] Loaded 1 contacts for 2025-12-10
🔍 [DailyContacts] Fetching photo URL for userId: eU1lNB3Q5dhcd7ysLWq2fNvze1l2
📸 [DailyContacts] Photo URL for ...: https://...
```

**失敗している場合 (現在):**
```
❌ [DailyContacts] Error loading contacts: [FirebaseError: Missing or insufficient permissions]
```

---

## 🔒 セキュリティに関する注意

### ✅ 安全な理由

1. **認証が必須**: `if request.auth != null`
2. **アプリ側でフィルタ**: `where('userId', isEqualTo: user.uid)`
3. **他のユーザーのデータは取得されない**

### ⚠️ 本番環境での推奨事項

開発環境では`allow read: if request.auth != null`でOKですが、
本番環境では以下のようにより厳密なルールを設定することをお勧めします:

```javascript
// より厳密なルール (本番環境用)
match /call_recordings/{recordingId} {
  allow read: if request.auth != null && 
                 (request.auth.uid == resource.data.userId ||
                  request.auth.uid in resource.data.participants);
  allow write: if request.auth != null && request.auth.uid == request.resource.data.userId;
}
```

---

## 💡 まとめ

1. **Firebase Console → Firestore → Rules**
2. **上記の推奨ルールをコピー&ペースト**
3. **「公開」をクリック**
4. **ブラウザをリロード**
5. **テスト!**

---

**一緒に解決しましょう!** 💪✨
