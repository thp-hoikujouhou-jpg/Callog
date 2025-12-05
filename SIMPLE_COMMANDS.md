# 🚀 Cloud Functions を公開する - 簡単な手順

## 📋 あなたがすべきこと

gcloud CLI をインストールされたんですね! 以下のコマンドを**順番に**実行してください。

---

## 🔐 ステップ1: Google Cloud にログイン

```bash
gcloud auth login
```

**何が起こるか:**
- ブラウザが開きます
- Googleアカウントでログインします
- 「Google Cloud SDK に権限を付与しますか?」→ **許可** をクリック
- ターミナルに戻って「認証が完了しました」と表示されます

---

## 📌 ステップ2: プロジェクトを設定

```bash
gcloud config set project callog-30758
```

**期待される出力:**
```
Updated property [core/project].
```

---

## 🔓 ステップ3: generateAgoraToken を公開

```bash
gcloud functions add-iam-policy-binding generateAgoraToken \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758
```

**期待される出力:**
```
Updated IAM policy for function [generateAgoraToken].
bindings:
- members:
  - allUsers
  role: roles/cloudfunctions.invoker
etag: BwYh...
version: 1
```

---

## 🔓 ステップ4: sendPushNotification を公開

```bash
gcloud functions add-iam-policy-binding sendPushNotification \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758
```

**期待される出力:**
```
Updated IAM policy for function [sendPushNotification].
bindings:
- members:
  - allUsers
  role: roles/cloudfunctions.invoker
etag: BwYh...
version: 1
```

---

## 🧪 ステップ5: 動作確認

### テスト1: generateAgoraToken

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

**期待される出力 (成功):**
```json
{
  "data": {
    "token": null,
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test",
    "uid": 0,
    "message": "Token generation disabled - App Certificate not configured"
  }
}
```

**失敗の場合 (HTMLエラー):**
```html
<html><head>
<title>403 Forbidden</title>
...
```
→ 権限設定がまだ反映されていません。1分待ってから再度実行してください。

### テスト2: sendPushNotification

```bash
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/sendPushNotification \
  -H "Content-Type: application/json" \
  -d '{"data":{"peerId":"test","channelId":"test","callType":"voice_call","callerName":"テストユーザー","callerId":"test"}}'
```

**期待される出力 (エラーが正常):**
```json
{
  "error": "Peer user not found"
}
```

これは正常です! 関数は動作していますが、テストユーザーが存在しないためエラーが返っています。

---

## ✅ ステップ6: Flutterアプリで最終確認

1. **ブラウザでアプリをリロード**
   - URL: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
   - Ctrl + Shift + R を押す

2. **通話機能をテスト**
   - ログイン
   - 友達を選択
   - 音声通話またはビデオ通話を開始

3. **コンソール確認** (F12キー)
   ```
   ✅ [AgoraToken] ✅ Token generated successfully
   ✅ [Push] ✅ Notification sent successfully!
   ❌ CORSエラーが表示されない
   ```

---

## 🔍 トラブルシューティング

### エラー1: "gcloud: command not found"

**原因**: gcloud がPATHに追加されていない

**解決策1**: インストールディレクトリを確認
```bash
# Google Cloud SDK のインストール場所を探す
find ~ -name "gcloud" -type f 2>/dev/null

# 見つかったパスを使用
/path/to/google-cloud-sdk/bin/gcloud auth login
```

**解決策2**: PATHに追加
```bash
# .bashrc または .zshrc に追加
export PATH=$PATH:/path/to/google-cloud-sdk/bin

# 変更を反映
source ~/.bashrc
```

**解決策3**: Firebase Console を使用
gcloud CLI が動作しない場合は、Firebase Console で手動設定してください:
1. https://console.firebase.google.com/
2. Callog → Functions
3. 各関数の Permissions で `allUsers` を追加

### エラー2: "You do not have permission to access project"

**原因**: ログインしたGoogleアカウントがCallogプロジェクトのオーナーではない

**解決策**:
```bash
# 別のアカウントでログイン
gcloud auth login --account=your-email@gmail.com

# アカウント一覧を確認
gcloud auth list

# 正しいアカウントに切り替え
gcloud config set account your-email@gmail.com
```

### エラー3: "Function generateAgoraToken does not exist"

**原因**: 関数がまだ存在しない、またはリージョンが違う

**解決策**:
```bash
# 関数の存在確認
gcloud functions list --project=callog-30758

# リージョンを確認して正しいリージョンを指定
```

---

## 📋 完全なコマンドリスト (コピペ用)

以下を順番に実行してください:

```bash
# 1. ログイン
gcloud auth login

# 2. プロジェクト設定
gcloud config set project callog-30758

# 3. generateAgoraToken を公開
gcloud functions add-iam-policy-binding generateAgoraToken \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758

# 4. sendPushNotification を公開
gcloud functions add-iam-policy-binding sendPushNotification \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=callog-30758

# 5. 動作確認
curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

---

## 🎯 まとめ

### やること
1. `gcloud auth login` - ログイン
2. `gcloud config set project callog-30758` - プロジェクト設定
3. `gcloud functions add-iam-policy-binding ...` - 関数を公開 (2回実行)
4. `curl ...` - テスト
5. Flutterアプリで動作確認

### 所要時間
約3〜5分

### 成功の証拠
- cURL コマンドでJSONレスポンスが返る
- Flutterアプリで通話が開始できる
- コンソールにCORSエラーが表示されない

---

**最終更新**: 2024-12-04
**ステータス**: gcloud CLI コマンド実行待ち
