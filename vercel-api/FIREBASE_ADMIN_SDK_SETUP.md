# 🔥 Firebase Admin SDK セットアップガイド

## ✅ 組織ポリシー削除成功

おめでとうございます！プロジェクトレベルの組織ポリシーが正常に削除されました。

```
Deleted [<Empty>].
```

これで Service Account Key が作成できるようになりました。

---

## 🎯 完全なセットアップ手順

### ⏰ Step 1: 5-10分待機 (重要)

ポリシーの削除後、**システム全体に反映されるまで5-10分かかります**。

**PowerShell で待機:**
```powershell
# 10分待機
Start-Sleep -Seconds 600
Write-Host "✅ 待機完了。キー作成を試行できます。"
```

**または手動で待機してください。**

---

### 🔑 Step 2: Service Account Key を作成

#### 方法 1: Firebase Console 経由 (推奨) ✅

1. **Firebase Console を開く:**
   ```
   https://console.firebase.google.com/project/callog-30758/settings/serviceaccounts/adminsdk
   ```

2. **「新しい秘密鍵の生成」ボタンをクリック**

3. **「キーを生成」をクリック**

4. **JSON ファイルがダウンロードされます**
   - ファイル名例: `callog-30758-firebase-adminsdk-xxxxx.json`
   - 保存先: `C:\Users\admin\Downloads\`

---

#### 方法 2: gcloud CLI 経由

```powershell
# Cloud SDK ディレクトリに移動
cd "C:\Users\admin\AppData\Local\Google\Cloud SDK"

# キーを作成
gcloud iam service-accounts keys create C:\Users\admin\Downloads\firebase-admin-key.json --iam-account=firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

**成功した場合の出力:**
```
created key [abc123def456] of type [json] as [C:\Users\admin\Downloads\firebase-admin-key.json]
```

**失敗した場合:**
- さらに5-10分待ってから再試行
- 組織レベルのポリシーも確認

---

### 📝 Step 3: JSON を単一行に変換

Vercel の環境変数に設定するため、JSON を単一行に変換します。

**PowerShell で実行:**
```powershell
# JSON ファイルのパスを指定 (実際のファイル名に置き換えてください)
$jsonPath = "C:\Users\admin\Downloads\callog-30758-firebase-adminsdk-xxxxx.json"

# JSON を読み込んで単一行に変換
$json = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
$singleLine = $json | ConvertTo-Json -Compress

# クリップボードにコピー
Set-Clipboard -Value $singleLine

# 確認メッセージ
Write-Host "✅ JSON がクリップボードにコピーされました (単一行形式)"
Write-Host ""
Write-Host "次のステップ:"
Write-Host "1. Vercel 設定画面を開く"
Write-Host "2. 環境変数名: FIREBASE_SERVICE_ACCOUNT"
Write-Host "3. Ctrl + V で貼り付け"
Write-Host "4. Sensitive にチェック"
Write-Host "5. すべての環境 (Production, Preview, Development) にチェック"
```

**出力例:**
```
✅ JSON がクリップボードにコピーされました (単一行形式)

次のステップ:
1. Vercel 設定画面を開く
2. 環境変数名: FIREBASE_SERVICE_ACCOUNT
3. Ctrl + V で貼り付け
4. Sensitive にチェック
5. すべての環境 (Production, Preview, Development) にチェック
```

---

### 🌐 Step 4: Vercel 環境変数に追加

1. **Vercel 設定画面を開く:**
   ```
   https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
   ```

2. **「環境変数を追加」ボタンをクリック**

3. **以下を入力:**

| 項目 | 値 |
|------|-----|
| **Name** | `FIREBASE_SERVICE_ACCOUNT` |
| **Value** | (Ctrl + V でクリップボードから貼り付け) |
| **Environment** | ✅ Production, ✅ Preview, ✅ Development |
| **Sensitive** | ✅ **必ずチェック** |

4. **「保存」ボタンをクリック**

---

### 📦 Step 5: 最新の Vercel プロジェクトをダウンロード

**ダウンロード URL:**
```
https://www.genspark.ai/api/files/s/A97XCbxJ
```

**ファイル名:** `callog-api-v2-firebase-admin-sdk.tar.gz`

**展開先:** `C:\Users\admin\Downloads\callog-api-v2`

---

### 🚀 Step 6: Vercel に再デプロイ

```powershell
# プロジェクトディレクトリに移動
cd C:\Users\admin\Downloads\callog-api-v2

# Vercel にデプロイ
vercel --prod
```

**プロンプトへの回答:**
- **Set up and deploy?** → `Y`
- **Which scope?** → あなたのアカウントを選択
- **Link to existing project?** → `Y`
- **Project name?** → `callog-api-v2`
- **Override settings?** → `N`

**デプロイ完了の確認:**
```
✅ Production: https://callog-api-v2.vercel.app [1s]
```

---

### 🧪 Step 7: API エンドポイントをテスト

**PowerShell でテスト:**
```powershell
$body = @{
    data = @{
        fcmToken = "test_fcm_token_12345"
        callType = "voice_call"
        callerName = "Test User"
        channelId = "test_channel_123"
        callerId = "test_caller_123"
        peerId = "test_peer_456"
    }
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://callog-api-v2.vercel.app/api/sendPushNotification" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

**期待される出力:**
```powershell
data
----
@{success=True; messageId=0:1234567890123456%abc123; message=Push notification sent successfully via Firebase Admin SDK; method=FCM HTTP v1 API; timestamp=1234567890123}
```

**または (エラーの場合):**
```powershell
error   : Failed to send notification
message : The registration token is not a valid FCM registration token
code    : messaging/invalid-registration-token
```
(これは正常です - テスト用の FCM トークンなので)

---

## 🔧 トラブルシューティング

### Error: "FIREBASE_SERVICE_ACCOUNT environment variable may be missing"

**原因:** 環境変数が設定されていない、または Vercel に反映されていない。

**解決策:**
1. Vercel 設定画面で `FIREBASE_SERVICE_ACCOUNT` が設定されているか確認
2. すべての環境 (Production, Preview, Development) にチェックが入っているか確認
3. `vercel --prod` で再デプロイ

---

### Error: "Firebase Service Account credentials are invalid"

**原因:** JSON が正しく変換されていない、または改行が含まれている。

**解決策:**
1. PowerShell のコマンドを再実行して単一行に変換
2. Vercel の環境変数を削除して再設定
3. 再デプロイ

---

### Error: "PERMISSION_DENIED" (キー作成時)

**原因:** ポリシーがまだ反映されていない。

**解決策:**
1. さらに5-10分待つ
2. 組織レベルのポリシーも確認:
   ```powershell
   gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --organization=YOUR_ORG_ID
   ```
3. 新しい Service Account を作成 (代替案):
   ```powershell
   gcloud iam service-accounts create callog-api-sa --display-name="Callog API SA"
   gcloud projects add-iam-policy-binding callog-30758 --member="serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com" --role="roles/firebase.admin"
   gcloud iam service-accounts keys create C:\Users\admin\Downloads\callog-api-sa-key.json --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
   ```

---

### Error: "Could not load the default credentials" (Vercel ログ)

**原因:** `FIREBASE_SERVICE_ACCOUNT` 環境変数が設定されていない。

**解決策:**
1. Vercel Deployment Logs を確認:
   ```
   https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2
   ```
2. 最新のデプロイのログを開く
3. `Environment Variables` セクションで `FIREBASE_SERVICE_ACCOUNT` があるか確認
4. なければ Step 4 を再実行

---

## 📊 完全な環境変数リスト

Vercel に設定する環境変数:

| 変数名 | 値 | 必須 | Sensitive |
|--------|-----|------|-----------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ | ❌ |
| `FIREBASE_SERVICE_ACCOUNT` | (JSON 単一行) | ✅ | ✅ |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ | ❌ |
| `AGORA_APP_CERTIFICATE` | (Agora Console から取得) | ✅ | ✅ |
| `FIREBASE_WEB_API_KEY` | `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA` | ❌ | ❌ |

**注意:** `FIREBASE_WEB_API_KEY` は Firebase Admin SDK 使用時は不要です。

---

## 🎯 新しいアーキテクチャ

### 変更点

**Before (Web API Key 方式):**
```
Flutter → Vercel API → FCM Legacy API (Web API Key)
```

**After (Firebase Admin SDK 方式):**
```
Flutter → Vercel API → Firebase Admin SDK → FCM HTTP v1 API
```

### メリット

✅ **FCM HTTP v1 API** (最新の API)
✅ **より詳細なエラーメッセージ**
✅ **より多くの機能** (優先度設定、プラットフォーム別設定など)
✅ **Legacy API の廃止予定に備える**

---

## 🧪 実際の通話テスト

### 2つのブラウザタブで:

**Tab 1 (発信者 - User A):**
1. Callog アプリを開く: `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai`
2. User A でログイン
3. 友達 (User B) を選択
4. 音声通話またはビデオ通話を開始

**Tab 2 (受信者 - User B):**
1. Callog アプリを開く: `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai`
2. User B でログイン
3. **別のタブに切り替える** (Gmail、YouTube など)
4. **デスクトップ通知を待つ** 🔔

**期待される動作:**

User B がバックグラウンドでもデスクトップ通知が届く:
```
┌──────────────────────────────────┐
│ 🔔 Callog                        │
│                                  │
│ 📞 [User A Name]から音声通話着信  │
│                                  │
│ [クリックして応答]                 │
└──────────────────────────────────┘
```

**Console Logs (Tab 1 - 発信者):**
```
[Push] 📤 Sending notification via Vercel API
[Push] 🔍 Fetching FCM token for peer: user_b_id
[Push] ✅ Peer FCM token found: d5A3-3dQg...
[Push] ✅ Notification sent successfully!
[Push] Message ID: 0:1234567890123456%abc123
```

---

## 📋 セットアップチェックリスト

完了したらチェック:

- [ ] **Step 1:** 5-10分待機した
- [ ] **Step 2:** Service Account Key を作成した (Firebase Console または gcloud CLI)
- [ ] **Step 3:** JSON を単一行に変換した
- [ ] **Step 4:** Vercel に環境変数 `FIREBASE_SERVICE_ACCOUNT` を追加した
- [ ] **Step 5:** 最新の Vercel プロジェクトをダウンロードした
- [ ] **Step 6:** `vercel --prod` で再デプロイした
- [ ] **Step 7:** API エンドポイントをテストした
- [ ] **Bonus:** 2つのブラウザタブで実際の通話をテストした

---

## 🚀 次のステップ

### すぐにやるべきこと

1. **⏰ 5-10分待つ** (ポリシー反映のため)
2. **🔑 Service Account Key を作成** (Firebase Console 推奨)
3. **📝 JSON を単一行に変換** (PowerShell コマンド)
4. **🌐 Vercel に環境変数を追加**
5. **📦 最新プロジェクトをダウンロード** (`https://www.genspark.ai/api/files/s/A97XCbxJ`)
6. **🚀 Vercel に再デプロイ** (`vercel --prod`)
7. **🧪 テスト** (API エンドポイント → 実際の通話)

---

## 📞 サポート

問題が発生した場合:

1. **Vercel Deployment Logs を確認:**
   `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2`

2. **Flutter アプリの Console Logs を確認:**
   - `F12` → Console タブ
   - `[Push]` メッセージを探す

3. **環境変数を再確認:**
   `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables`

---

**推定セットアップ時間:** 15-20分 (待機時間含む)

**次のステップ:** ⏰ 5-10分待ってから Service Account Key を作成してください！ 🎯
