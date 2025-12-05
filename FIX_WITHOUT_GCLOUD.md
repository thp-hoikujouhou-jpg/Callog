# ✅ gcloud CLI なしでの解決方法

## 📊 現在の状況

### ✅ サービス状態
- **Flutter Webサーバー**: 正常稼働中
- **ポート**: 5060
- **HTTP Status**: 200 OK
- **応答時間**: 0.001秒
- **プレビューURL**: https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

**→ サービスの再起動は不要です!**

### ⚠️ 未解決の問題
- Cloud Functions の IAM Policy (公開権限) が未設定

### ❌ gcloud CLI の状態
- **インストール状況**: 未インストール
- **必要性**: なし（Firebase Consoleで解決可能）

---

## 🟢 推奨解決方法: Firebase Console（gcloud 不要）

### なぜこの方法がベストか？
- ✅ gcloud CLI のインストール不要
- ✅ ブラウザだけで完結
- ✅ 視覚的でわかりやすい
- ✅ 最も確実

---

## 📋 手順（5分で完了）

### ステップ1: Firebase Console にアクセス

1. ブラウザで開く: **https://console.firebase.google.com/**
2. **Callog** プロジェクトをクリック
3. 左側のメニューから **Functions** を選択

### ステップ2: generateAgoraToken の権限設定

関数リストに **generateAgoraToken** が表示されているはずです。

1. **generateAgoraToken** 関数の右側にある **︙** (3点メニュー) をクリック
2. **Permissions** を選択
3. **ADD PRINCIPAL** ボタンをクリック
4. ダイアログが開いたら、以下を入力:
   - **New principals**: `allUsers`
   - **Select a role**: `Cloud Functions Invoker` を選択
5. **SAVE** ボタンをクリック

**確認**: 権限リストに `allUsers` が表示されます。

### ステップ3: sendPushNotification の権限設定

同じ手順を **sendPushNotification** 関数にも実施します。

1. **sendPushNotification** 関数の右側にある **︙** をクリック
2. **Permissions** を選択
3. **ADD PRINCIPAL** をクリック
4. 以下を入力:
   - **New principals**: `allUsers`
   - **Select a role**: `Cloud Functions Invoker`
5. **SAVE** をクリック

### ステップ4: 設定の確認

両方の関数で以下が表示されていることを確認:

```
Principal: allUsers
Role: Cloud Functions Invoker
```

---

## 🧪 動作確認

### 方法1: ブラウザのコンソールで確認

1. 新しいブラウザタブで以下を開く:
   ```
   https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai
   ```

2. **F12** キーを押してコンソールを開く

3. 以下のコードを貼り付けて **Enter**:
   ```javascript
   fetch('https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken', {
     method: 'POST',
     headers: {'Content-Type': 'application/json'},
     body: JSON.stringify({data: {channelName: 'test', uid: 0, role: 'publisher'}})
   })
   .then(res => res.json())
   .then(data => console.log('✅ Success:', data))
   .catch(err => console.error('❌ Error:', err));
   ```

**期待される結果:**
```javascript
✅ Success: {
  data: {
    token: null,
    appId: "d1a8161eb70448d89eea1722bc169c92",
    channelName: "test",
    uid: 0,
    message: "Token generation disabled - App Certificate not configured"
  }
}
```

### 方法2: Flutterアプリで通話テスト

1. **Ctrl + Shift + R** でアプリをリロード
2. ログインして友達を選択
3. 音声通話またはビデオ通話を開始
4. コンソール (F12) で以下のログを確認:

**成功の場合:**
```
[AgoraToken] 🎫 Generating token for channel: call_xxx
[AgoraToken] ✅ Token generated successfully
[Push] 📤 Sending notification via Cloud Functions
[Push] ✅ Notification sent successfully!
```

**失敗の場合 (権限未設定):**
```
[AgoraToken] ❌ Error generating token: [firebase_functions/permission-denied]
```

---

## 📸 Firebase Console のスクリーンショット説明

### 画面1: Functions 一覧
```
Functions
┌─────────────────────────────────────────┐
│ generateAgoraToken         ︙          │ ← ここをクリック
│ sendPushNotification       ︙          │
│ cleanupOldNotifications    ︙          │
└─────────────────────────────────────────┘
```

### 画面2: メニュー
```
︙ メニュー
┌─────────────────┐
│ View logs       │
│ Permissions     │ ← ここをクリック
│ Delete function │
└─────────────────┘
```

### 画面3: Permissions ダイアログ
```
Permissions for generateAgoraToken
┌─────────────────────────────────────┐
│ Principal          | Role            │
│ (empty)                              │
│                                      │
│ [ADD PRINCIPAL]  [ADD CONDITION]    │ ← ここをクリック
└─────────────────────────────────────┘
```

### 画面4: Add Principal
```
Add principals
┌─────────────────────────────────────┐
│ New principals                      │
│ [allUsers________________]          │ ← ここに入力
│                                      │
│ Select a role                       │
│ [Cloud Functions Invoker_]          │ ← ここを選択
│                                      │
│         [CANCEL]  [SAVE]            │ ← SAVEをクリック
└─────────────────────────────────────┘
```

### 画面5: 設定完了
```
Permissions for generateAgoraToken
┌─────────────────────────────────────┐
│ Principal          | Role            │
│ allUsers           | Cloud Functions │ ← 表示されればOK
│                    | Invoker         │
└─────────────────────────────────────┘
```

---

## ⚠️ トラブルシューティング

### 問題1: "Permissions" メニューが表示されない

**原因**: 権限不足

**解決策**:
1. Firebaseプロジェクトのオーナーまたは編集者権限があることを確認
2. Google Cloud Console で確認: https://console.cloud.google.com/
3. IAM & Admin → IAM で自分のアカウントのロールを確認
4. 必要なロール: `Owner`, `Editor`, または `Cloud Functions Admin`

### 問題2: "allUsers" が見つからない

**解決策**:
- `allUsers` を手動で入力してください（コピペ推奨）
- 大文字小文字を正確に: `allUsers` (小文字の"all"、大文字の"U"）

### 問題3: 権限設定後もエラーが出る

**解決策**:
1. ブラウザのキャッシュをクリア
2. シークレットモードで開く
3. 5分ほど待つ（設定の反映に時間がかかることがある）
4. Firebase Console で権限が正しく設定されているか再確認

---

## 🎯 チェックリスト

設定前:
- [ ] Firebase Console にアクセスできる
- [ ] Callog プロジェクトが選択されている
- [ ] Functions メニューが開いている
- [ ] generateAgoraToken と sendPushNotification が表示されている

設定中:
- [ ] generateAgoraToken の Permissions を開いた
- [ ] ADD PRINCIPAL をクリック
- [ ] `allUsers` と入力
- [ ] `Cloud Functions Invoker` を選択
- [ ] SAVE をクリック
- [ ] sendPushNotification にも同じ設定を実施

設定後:
- [ ] 両方の関数で `allUsers` が表示されている
- [ ] ブラウザコンソールでテスト成功
- [ ] Flutterアプリで通話機能が動作
- [ ] CORSエラーが表示されない

---

## 📊 現在の状態まとめ

| 項目 | 状態 |
|------|------|
| Flutter Webサーバー | ✅ 稼働中 |
| サービス再起動 | ✅ 不要 |
| Cloud Functions 作成 | ✅ 完了 |
| IAM Policy 設定 | ⏳ 作業中（あなたが実施） |
| gcloud CLI | ❌ 不要（Firebase Consoleで解決） |

---

## 🚀 次のステップ

1. **Firebase Console で権限設定** (上記の手順に従う)
2. **ブラウザコンソールでテスト** (fetch コマンド実行)
3. **Flutterアプリをリロード** (Ctrl + Shift + R)
4. **通話機能をテスト** (友達に通話をかける)
5. **成功を確認** (コンソールログを確認)

---

## 💡 まとめ

### gcloud CLI は不要です！

**Firebase Console だけで完結**します:
1. Functions → 関数を選択
2. ︙ → Permissions
3. ADD PRINCIPAL → `allUsers` + `Cloud Functions Invoker`
4. SAVE

**所要時間**: 5分以内 ⚡

**結果**: Cloud Functions が Web から呼び出し可能になります 🎉

---

**最終更新**: 2024-12-04
**サービス状態**: 正常稼働中
**gcloud CLI**: 不要
**作業場所**: Firebase Console のみ
