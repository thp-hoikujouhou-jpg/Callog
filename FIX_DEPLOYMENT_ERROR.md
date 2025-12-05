# 🔧 デプロイエラーの解決方法

## ❌ 発生したエラー

```
Error: [generateAgoraToken(us-central1)] Changing from a callable function to an HTTPS function is not allowed. 
Please delete your function and create a new one instead.
```

## 🎯 原因

Firebase Cloud Functionsでは、関数の種類を変更することは許可されていません:
- `onCall` (Callable関数) → `onRequest` (HTTPS関数)

この変更を行うには、**古い関数を削除してから新しい関数をデプロイ**する必要があります。

---

## ✅ 解決方法 (2つの選択肢)

### 🟢 方法1: Firebase Consoleで削除 (推奨 - 簡単)

#### ステップ1: Firebase Consoleにアクセス
1. https://console.firebase.google.com/ を開く
2. **Callog** プロジェクトを選択
3. 左メニューから **Functions** をクリック

#### ステップ2: 古い関数を削除
1. **generateAgoraToken** を見つける
2. 右側の **︙** (3点メニュー) をクリック
3. **Delete function** を選択
4. 確認ダイアログで **DELETE** をクリック

5. **sendPushNotification** も同様に削除
6. 右側の **︙** をクリック
7. **Delete function** を選択
8. **DELETE** をクリック

#### ステップ3: 新しい関数をデプロイ
```bash
cd /home/user/Callog
firebase deploy --only functions
```

---

### 🟡 方法2: コマンドラインで削除 (高度)

#### ステップ1: 古い関数を削除

```bash
cd /home/user/Callog

# generateAgoraToken を削除
firebase functions:delete generateAgoraToken --region us-central1

# sendPushNotification を削除
firebase functions:delete sendPushNotification --region us-central1
```

各コマンド実行時に確認メッセージが表示されます:
```
? Are you sure you want to delete generateAgoraToken(us-central1)? (y/N)
```
**y** を入力して Enter を押してください。

#### ステップ2: 削除の確認

```bash
firebase functions:list
```

**期待される結果**: 何も表示されない (= すべての関数が削除された)

#### ステップ3: 新しい関数をデプロイ

```bash
firebase deploy --only functions
```

---

## 🚀 デプロイ成功後の確認

### 成功メッセージ

```
✔  functions: Finished running predeploy script.
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (XX.XX KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 20 function generateAgoraToken(us-central1)...
i  functions: creating Node.js 20 function sendPushNotification(us-central1)...
✔  functions[generateAgoraToken(us-central1)]: Successful create operation.
✔  functions[sendPushNotification(us-central1)]: Successful create operation.

✔  Deploy complete!
```

**ポイント**: `creating` (作成中) と表示されることを確認してください。
(前回は `updating` でしたが、今回は新しい関数なので `creating` になります)

### Firebase Consoleで確認

1. https://console.firebase.google.com/
2. Callog プロジェクト → Functions
3. 以下の2つの関数が表示されていることを確認:
   - ✅ **generateAgoraToken** (Type: HTTPS)
   - ✅ **sendPushNotification** (Type: HTTPS)

---

## 🧪 動作テスト

### 1. Flutterアプリをリロード

ブラウザで https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai を開き、
**Ctrl + Shift + R** (強制リロード) を実行

### 2. 通話機能をテスト

1. アプリにログイン
2. 友達を選択
3. 音声通話またはビデオ通話を開始
4. ブラウザのコンソールを確認 (F12キー)

### 3. 成功の確認

**期待されるログ:**
```
[AgoraToken] 🎫 Generating token for channel: call_xxx
[AgoraToken] ✅ Token generated successfully
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
```

**❌ CORSエラーが表示されない** ことを確認してください!

---

## 🔍 トラブルシューティング

### エラー1: "Function not found"

削除コマンド実行時にこのエラーが出た場合:
```
Error: Function generateAgoraToken does not exist.
```

**対処法**: すでに削除されています。次のステップ (デプロイ) に進んでください。

### エラー2: "Permission denied"

```
Error: HTTP Error: 403, Permission denied
```

**対処法**: 
1. Firebase CLIに正しいアカウントでログインしているか確認:
   ```bash
   firebase login:list
   ```
2. 必要に応じて再ログイン:
   ```bash
   firebase logout
   firebase login
   ```

### エラー3: デプロイ後もCORSエラーが出る

**対処法**:
1. ブラウザのキャッシュをクリア
2. シークレットモードで開く
3. Flutterアプリを再ビルド:
   ```bash
   cd /home/user/Callog
   flutter clean
   flutter build web --release
   ```

---

## 📋 完全なコマンド手順 (コピペ用)

```bash
# ステップ1: プロジェクトディレクトリに移動
cd /home/user/Callog

# ステップ2: 古い関数を削除
firebase functions:delete generateAgoraToken --region us-central1
# 確認: y を入力

firebase functions:delete sendPushNotification --region us-central1
# 確認: y を入力

# ステップ3: 削除の確認
firebase functions:list
# 何も表示されなければOK

# ステップ4: 新しい関数をデプロイ
firebase deploy --only functions

# ステップ5: デプロイの確認
firebase functions:list
# generateAgoraToken と sendPushNotification が表示されればOK
```

---

## ⚠️ 重要な注意事項

### 削除中の一時的な影響

関数を削除してから再デプロイするまでの間 (約1〜2分)、以下の機能が一時的に使用できません:
- ❌ Agoraトークン生成
- ❌ プッシュ通知送信

**対策**: メンテナンス時間帯に実施するか、ユーザーが少ない時間帯に行ってください。

### データへの影響

**心配不要**: Firestore、Storage、Authenticationのデータには一切影響ありません。
削除されるのはCloud Functionsのコードだけです。

---

## ✅ チェックリスト

デプロイ作業前:
- [ ] Firebase Consoleにアクセスできる
- [ ] Firebase CLIにログインしている
- [ ] 既存の関数を削除する準備ができている

デプロイ作業後:
- [ ] `firebase functions:list` で新しい関数が表示される
- [ ] Firebase Consoleで関数が確認できる
- [ ] Flutterアプリで通話機能が動作する
- [ ] CORSエラーが表示されない

---

## 🎯 まとめ

1. **古い関数を削除** (Firebase Consoleまたはコマンドライン)
2. **新しい関数をデプロイ** (`firebase deploy --only functions`)
3. **動作確認** (通話機能をテスト)

これで完了です! 🚀

---

**最終更新**: 2024-12-04
**問題**: onCall → onRequest変更時のデプロイエラー
**解決策**: 既存の関数を削除してから再デプロイ
