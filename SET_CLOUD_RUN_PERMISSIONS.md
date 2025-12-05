# 🔐 Cloud Run パーミッション設定ガイド

## 問題: 403 Forbidden エラー

Cloud Functions (Cloud Run) が `403 Forbidden` を返すのは、**unauthenticated access (未認証アクセス) が許可されていない**ためです。

## ✅ 解決方法: Google Cloud Consoleで設定

### 手順 1: Google Cloud Consoleにアクセス

1. **Google Cloud Console**を開く: https://console.cloud.google.com/
2. **プロジェクト `callog-30758` を選択**

### 手順 2: Cloud Runサービスに移動

1. 左メニュー → **Cloud Run**をクリック
2. または直接アクセス: https://console.cloud.google.com/run?project=callog-30758

### 手順 3: generateAgoraToken サービスの権限を設定

1. **`generateagoratoken`** サービスをクリック
2. 上部の **"PERMISSIONS"** タブをクリック
3. **"+ ADD PRINCIPAL"** ボタンをクリック
4. **New principals** フィールドに `allUsers` と入力
5. **Role** ドロップダウンから **"Cloud Run Invoker"** を選択
6. **"SAVE"** をクリック

### 手順 4: sendPushNotification サービスの権限を設定

1. 戻って **`sendpushnotification`** サービスをクリック
2. 上部の **"PERMISSIONS"** タブをクリック
3. **"+ ADD PRINCIPAL"** ボタンをクリック
4. **New principals** フィールドに `allUsers` と入力
5. **Role** ドロップダウンから **"Cloud Run Invoker"** を選択
6. **"SAVE"** をクリック

## ⚠️ 警告メッセージについて

設定中に以下のような警告が表示される場合があります:

```
Warning: This resource is public and can be accessed by anyone on the internet.
```

**これは正常です!** Web アプリケーションから直接呼び出すため、パブリックアクセスが必要です。

**セキュリティ対策**:
- Cloud Functions内でFirebase Authトークン検証を実装済み
- 認証済みユーザーのみが実際の操作を実行可能
- CORSヘッダーで特定ドメインからのアクセスのみ許可

## 🧪 設定後の確認

### テスト 1: OPTIONS preflightリクエスト

```bash
curl -X OPTIONS https://generateagoratoken-eyix4hluza-uc.a.run.app \
  -H "Origin: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

**期待される結果**: HTTP 204 または 200 (403ではない)

### テスト 2: 実際のPOSTリクエスト

```bash
curl -X POST https://generateagoratoken-eyix4hluza-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

**期待される結果**: JSON レスポンス (403ではない)

## 🚀 Flutterアプリでのテスト

設定完了後:

1. **アプリを開く**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
2. **強制リフレッシュ**: Ctrl + Shift + R
3. **ログイン** → **通話テスト**

**期待される結果**:
```
✅ [AgoraToken] ✅ Token generated successfully
✅ [Push] ✅ Notification sent successfully!
```

**CORSエラーが表示されないこと**を確認してください。

## 📝 トラブルシューティング

### エラー: "You do not have permission to add principals"

**解決策**: Google Cloud プロジェクトの **Owner** または **Cloud Run Admin** 権限が必要です。
プロジェクトオーナーに権限付与を依頼してください。

### エラー: 組織ポリシーによりallUsersが禁止されている

**解決策**: 組織管理者に **`iam.allowedPolicyMemberDomains`** 制約の例外を申請してください。

または、代替方法として:
1. **Firebase Authentication必須化**: すべてのユーザーがログイン必須
2. **サービスアカウント使用**: Flutterアプリでサービスアカウントキーを使用

---

**重要**: この設定を行わないと、CORSエラーが解決しません。
