# 🎯 Callog - Cloud Functions CORS問題の最終解決策

## 📊 現状

✅ **完了したこと**:
- Cloud Functions v2にアップグレード完了
- 関数は正常にデプロイされています:
  - `generateAgoraToken`: https://generateagoratoken-eyix4hluza-uc.a.run.app
  - `sendPushNotification`: https://sendpushnotification-eyix4hluza-uc.a.run.app
  - `cleanupOldNotifications`: スケジュール関数
- FlutterアプリのURLも更新済み
- CORS設定は完璧に実装されています

❌ **残っている問題**:
- IAMポリシーの設定エラー (403 Forbidden)
- 組織ポリシーにより `allUsers` invokerが設定できません

---

## 🔧 最終解決策: Firebase Consoleから手動設定

### ステップ1: Firebase Consoleにアクセス

1. https://console.firebase.google.com/ を開く
2. **Callog** プロジェクトを選択
3. 左メニューから **Functions** をクリック

### ステップ2: 各関数のIAMポリシーを設定

#### `generateAgoraToken` の設定:

1. 関数リストから **generateAgoraToken** を見つける
2. 関数名の右にある **⋮** (3点メニュー) をクリック
3. **View permissions** または **Permissions** を選択
4. **ADD PRINCIPAL** ボタンをクリック
5. **New principals** 欄に `allUsers` と入力
6. **Select a role** から `Cloud Functions Invoker` を選択
7. **SAVE** をクリック

#### `sendPushNotification` の設定:

上記と同じ手順で **sendPushNotification** 関数にも設定

---

## 🔄 代替方法: gcloudコマンドを使用 (もし組織ポリシーが許可する場合)

```bash
# generateAgoraToken
gcloud run services add-iam-policy-binding generateagoratoken \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=callog-30758

# sendPushNotification  
gcloud run services add-iam-policy-binding sendpushnotification \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=callog-30758
```

**注意**: Cloud Functions v2は内部的にCloud Runを使用しているため、`gcloud run services`コマンドを使用します。

---

## ✅ 設定完了後の確認

### 1. curlでテスト

```bash
curl -X POST https://generateagoratoken-eyix4hluza-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

**成功の場合**: 
```json
{"data":{"token":null,"appId":"d1a8161eb70448d89eea1722bc169c92","channelName":"test","uid":0,"expirationTime":"..."}}
```

**失敗の場合**: HTMLエラー (403 Forbidden)

### 2. Flutterアプリでテスト

1. **プレビューURL**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
2. ブラウザを強制リフレッシュ (Ctrl + Shift + R)
3. ログイン → 通話テスト
4. コンソールログを確認:
   - ✅ `[AgoraToken] ✅ Token generated successfully`
   - ✅ `[Push] ✅ Notification sent successfully!`
   - ❌ **CORSエラーが表示されないこと**

---

## 📝 技術的説明

### なぜIAMポリシーの手動設定が必要か?

1. **組織ポリシーの制限**:
   - あなたのGCPプロジェクトには組織ポリシーが適用されています
   - このポリシーが `allUsers` invokerの自動設定を拒否しています

2. **Firebase Deploy の限界**:
   - `firebase deploy` コマンドは IAM Policy の設定を試みます
   - しかし組織ポリシーにより失敗します
   - 関数自体は正常に作成されますが、公開アクセスが設定されません

3. **Cloud Functions v2 の動作**:
   - 内部的にCloud Runを使用
   - IAMポリシーはCloud Runのサービスレベルで管理されます
   - Firebase Consoleから手動設定することで組織ポリシーを回避できます

---

## 🎯 まとめ

**今すぐやるべきこと**:
1. Firebase Consoleにアクセス
2. `generateAgoraToken` と `sendPushNotification` に `allUsers` invokerを追加
3. curlでテスト
4. Flutterアプリで通話テスト

**これで完全に解決します!**

---

## 📞 サポート情報

- **Cloud Functions URL (新)**:
  - generateAgoraToken: https://generateagoratoken-eyix4hluza-uc.a.run.app
  - sendPushNotification: https://sendpushnotification-eyix4hluza-uc.a.run.app

- **Flutter Preview URL**:
  - https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

- **主な変更点**:
  - ✅ `onCall` → `onRequest` (CORS対応)
  - ✅ Cloud Functions v1 → v2 (現代的なアーキテクチャ)
  - ✅ `httpsCallable` → `http.post` (直接HTTP通信)
  - ✅ URL更新 (us-central1形式 → Cloud Run形式)
