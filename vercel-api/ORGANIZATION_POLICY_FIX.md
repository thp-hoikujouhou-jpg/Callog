# 🔐 組織レベルのポリシー削除ガイド

## 🚨 問題

新しいService Accountを作成してもキー作成がブロックされる:

```
ERROR: FAILED_PRECONDITION: Key creation is not allowed on this service account.
type: constraints/iam.disableServiceAccountKeyCreation
```

これは**組織レベル**または**フォルダレベル**のポリシーが原因です。

---

## 🔍 Step 1: 組織IDを確認

```powershell
# 組織IDを取得
gcloud projects describe callog-30758 --format="value(parent)"
```

**出力例:**
```
organizations/123456789012
```
または
```
folders/987654321
```

組織IDまたはフォルダIDをメモしてください。

---

## 🔧 Step 2: 組織レベルのポリシーを確認

### 組織直下の場合

```powershell
# 組織IDを変数に設定 (出力された数字部分のみ)
$ORG_ID = "123456789012"  # ← あなたの組織IDに置き換え

# 組織レベルのポリシーを確認
gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --organization=$ORG_ID
```

### フォルダ配下の場合

```powershell
# フォルダIDを変数に設定
$FOLDER_ID = "987654321"  # ← あなたのフォルダIDに置き換え

# フォルダレベルのポリシーを確認
gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --folder=$FOLDER_ID
```

**出力例 (ポリシーが有効な場合):**
```yaml
constraint: constraints/iam.disableServiceAccountKeyCreation
etag: BwVUSr8Q7Ng=
booleanPolicy:
  enforced: true  # ← これが true の場合、キー作成が禁止されている
```

---

## 🗑️ Step 3: 組織レベルのポリシーを削除

### 組織レベルで削除

```powershell
# 組織レベルのポリシーを削除
gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --organization=$ORG_ID
```

**期待される出力:**
```
Deleted [<Empty>].
```

### フォルダレベルで削除 (該当する場合)

```powershell
# フォルダレベルのポリシーを削除
gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --folder=$FOLDER_ID
```

---

## ⏰ Step 4: 10-15分待機

ポリシーの削除は即座に反映されません。**10-15分**待機してください。

```powershell
# PowerShell で 15分待機
Write-Host "⏰ ポリシーの伝播を待機中... (15分)"
Start-Sleep -Seconds 900
Write-Host "✅ 待機完了！キー作成を試行できます。"
```

---

## 🔑 Step 5: キー作成を再試行

```powershell
# キー作成を再試行
gcloud iam service-accounts keys create C:\Users\admin\Downloads\callog-api-sa-key.json --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
```

**成功した場合:**
```
created key [abc123def456] of type [json] as [C:\Users\admin\Downloads\callog-api-sa-key.json]
```

✅ **これで成功するはずです！**

---

## 🚨 依然として失敗する場合

### Option A: 組織ポリシーの例外を設定

キー作成を完全に禁止する代わりに、**特定のService Accountのみ許可**できます。

```powershell
# ポリシーファイルを作成
@"
constraint: constraints/iam.disableServiceAccountKeyCreation
listPolicy:
  deniedValues:
    - "*"
  allowedValues:
    - "projects/callog-30758/serviceAccounts/callog-api-sa@callog-30758.iam.gserviceaccount.com"
"@ | Out-File -FilePath C:\Users\admin\Downloads\policy.yaml -Encoding UTF8

# ポリシーを適用
gcloud resource-manager org-policies set-policy C:\Users\admin\Downloads\policy.yaml --organization=$ORG_ID
```

### Option B: ADC を使用 (ローカル開発・テスト用)

Service Account Key を作成せず、個人アカウントで認証:

```powershell
gcloud auth application-default login
```

**用途:**
- ✅ ローカル開発・テスト
- ❌ 本番環境 (Vercel) では使用不可

### Option C: Web API Key 実装を使用 (推奨)

**Service Account Key を使わない実装**をそのまま使用:

```
https://www.genspark.ai/api/files/s/tlJ3yFkA
```

**メリット:**
- ✅ Service Account Key 不要
- ✅ 組織ポリシーの影響を受けない
- ✅ 既に動作している
- ✅ Vercel で使用可能

---

## 📊 完全なコマンド一覧

```powershell
# ===== Step 1: 組織IDを確認 =====
$PARENT = gcloud projects describe callog-30758 --format="value(parent)"
Write-Host "Parent: $PARENT"

# 組織IDまたはフォルダIDを抽出
if ($PARENT -match "organizations/(\d+)") {
    $ORG_ID = $Matches[1]
    Write-Host "✅ Organization ID: $ORG_ID"
} elseif ($PARENT -match "folders/(\d+)") {
    $FOLDER_ID = $Matches[1]
    Write-Host "✅ Folder ID: $FOLDER_ID"
}

# ===== Step 2: ポリシーを確認 =====
if ($ORG_ID) {
    gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --organization=$ORG_ID
} elseif ($FOLDER_ID) {
    gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --folder=$FOLDER_ID
}

# ===== Step 3: ポリシーを削除 =====
if ($ORG_ID) {
    gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --organization=$ORG_ID
} elseif ($FOLDER_ID) {
    gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --folder=$FOLDER_ID
}

# ===== Step 4: 15分待機 =====
Write-Host "⏰ ポリシーの伝播を待機中... (15分)"
Start-Sleep -Seconds 900

# ===== Step 5: キー作成を再試行 =====
gcloud iam service-accounts keys create C:\Users\admin\Downloads\callog-api-sa-key.json --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
```

---

## 🎯 推奨事項

### 今すぐできること

**Option 1: 組織レベルのポリシーを削除** (推奨)
- 組織管理者として実行可能
- 完全な解決策
- 10-15分の待機が必要

**Option 2: Web API Key 実装を使用** (最も簡単)
- Service Account Key 不要
- 組織ポリシーの影響を受けない
- **既に動作している**
- すぐに使える

---

## ✅ チェックリスト

確認してください:

- [ ] 組織IDまたはフォルダIDを確認した
- [ ] 組織/フォルダレベルのポリシーを確認した
- [ ] 組織/フォルダレベルのポリシーを削除した
- [ ] **10-15分待機した** (重要)
- [ ] キー作成を再試行した

---

## 🚀 次のステップ

どちらを選びますか？

1. **組織レベルのポリシーを削除して待機** (完全な解決)
2. **Web API Key 実装を使用** (Service Account Key 不要・すぐ使える) ✅

ご希望の方法をお聞かせください！
