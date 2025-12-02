# Callog - Troubleshooting Guide

## 🐛 通話画面が表示されない問題

### 症状
- 音声通話ボタンをクリック
- マイク権限の確認ダイアログが表示される
- 権限を許可しても通話画面が表示されない

### 🔍 原因の確認方法

#### 1. ブラウザのコンソールログを確認

**手順:**
1. ブラウザでCallogアプリを開く
2. `F12`キーを押して開発者ツールを開く
3. `Console`タブを選択
4. 音声通話ボタンをクリック
5. コンソールに表示されるログを確認

**期待されるログ:**
```
📞 Voice call button pressed (existing button)
📞 Requesting microphone permission...
🎤 Microphone permission granted: true
✅ Permission granted, navigating to call screen...
📱 OutgoingVoiceCallScreen initialized
🔧 Initializing WebRTC call...
✅ Current user: [USER_ID]
🔌 Initializing WebRTC service...
🔌 Connecting to signaling server: wss://8765-xxx.sandbox.novita.ai
✅ WebRTC service initialized for user: [USER_ID]
📞 Starting call to [FRIEND_ID]
```

**エラーの例:**

##### A. Firebase権限エラー
```
❌ Error: [firebase_auth/permission-denied] Missing or insufficient permissions
```
**解決方法:** Firestoreセキュリティルールを設定する（下記参照）

##### B. シグナリングサーバー接続エラー
```
❌ WebSocket connection failed: [error]
```
**解決方法:** シグナリングサーバーが稼働しているか確認

##### C. マイク権限エラー
```
❌ Failed to get microphone access: NotAllowedError
```
**解決方法:** ブラウザの設定でマイク権限を許可

---

## 🔥 Firebase Firestore セキュリティルールの設定

### 必須設定

通話機能を使用するには、Firestoreのセキュリティルールを設定する必要があります。

#### 手順:

**1. Firebase Consoleにアクセス**
```
https://console.firebase.google.com/project/callog-30758/firestore/rules
```

**2. 左側メニューから「Firestore Database」を選択**

**3. 「ルール」タブをクリック**

**4. 「ルールを編集」をクリック**

**5. 以下のルールをコピー＆ペースト:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to read all users (for friend lists)
    match /users/{userId} {
      allow read: if request.auth != null;
    }
    
    // Messages - allow authenticated users
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    // Chats - allow authenticated users
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }
    
    // Call history - allow authenticated users to read/write
    match /calls/{callId} {
      allow read, write: if request.auth != null;
    }
    
    // Voice call signaling - allow authenticated users
    match /voiceCalls/{callId} {
      allow read, write: if request.auth != null;
    }
    
    // Friend requests
    match /friendRequests/{requestId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**6. 「公開」ボタンをクリック**

**7. デプロイが完了するまで数秒待つ**

**8. ✅ 設定完了！アプリをリロードして再度試してください**

---

## 🔌 シグナリングサーバーの確認

### シグナリングサーバーが稼働しているか確認

**コマンド:**
```bash
ps aux | grep signaling_server | grep -v grep
```

**期待される出力:**
```
user  22450  python3 signaling_server.py
```

### シグナリングサーバーのURL

**本番URL:**
```
wss://8765-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
```

### シグナリングサーバーが停止している場合

**再起動コマンド:**
```bash
cd /home/user/signaling_server
python3 signaling_server.py &
```

---

## 🎤 マイク権限の問題

### ブラウザでマイク権限を確認

**Chrome:**
1. URLバー左側の🔒アイコンをクリック
2. 「サイトの設定」を選択
3. 「マイクロフォン」を「許可」に設定
4. ページをリロード

**Firefox:**
1. URLバー左側の🔒アイコンをクリック
2. 「接続の安全性を確認」を選択
3. 「詳細を表示」をクリック
4. 「権限」タブでマイクを「許可」に設定
5. ページをリロード

---

## 📱 テスト手順

### 正常な通話テスト

**1. 2つのブラウザタブでCallogを開く**
- タブ1: ユーザーA でログイン
- タブ2: ユーザーB でログイン

**2. 友達リストにお互いを追加**

**3. タブ1で:**
- Chatタブに移動
- ユーザーBを選択
- 上部の緑色の電話アイコンをクリック
- マイク権限を許可
- ローディング画面「Connecting...」が表示される
- 通話画面が表示される

**4. タブ2で:**
- 着信通知が表示される（実装予定）
- 応答すると通話が開始される

---

## 🆘 それでも解決しない場合

### デバッグ情報の収集

**1. ブラウザのコンソールログ全体をコピー**
```
開発者ツール (F12) > Console > 右クリック > Save as...
```

**2. ネットワークログを確認**
```
開発者ツール (F12) > Network > WS (WebSocket) タブ
```

**3. 以下の情報を確認:**
- ブラウザの種類とバージョン
- OS（Windows/Mac/Linux）
- ログインしているユーザーID
- 通話しようとしている相手のユーザーID
- エラーメッセージ全文

### サポート連絡先

エラーログと上記の情報を添えて、開発チームにお問い合わせください。

---

## ✅ チェックリスト

通話機能が動作するために必要な要件:

- [ ] Firebaseプロジェクトが作成されている
- [ ] Firestoreデータベースが有効化されている
- [ ] **Firestoreセキュリティルールが設定されている** ⭐ 重要
- [ ] Firebase Authenticationが有効化されている
- [ ] シグナリングサーバーが稼働している
- [ ] ブラウザでマイク権限が許可されている
- [ ] HTTPS接続でアプリにアクセスしている
- [ ] 両方のユーザーがログインしている
- [ ] 両方のユーザーが友達関係にある

---

## 🎉 成功の確認

通話が正常に開始されると、以下のような動作になります:

1. ✅ 通話ボタンをクリック
2. ✅ マイク権限を許可
3. ✅ 「Connecting...」ローディング画面が表示
4. ✅ 通話画面が表示（相手のアバター、通話時間、コントロールボタン）
5. ✅ 相手が応答すると音声が聞こえる
6. ✅ ミュート、スピーカー、終了ボタンが動作する

---

最終更新: 2024年12月2日
バージョン: 1.0
