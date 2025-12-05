# 🔧 Service Account Key 取得トラブルシューティング

## 🚨 問題: 組織ポリシーを変更しても Service Account Key が取得できない

---

## 🔍 考えられる原因

### 1️⃣ 組織ポリシーの伝播遅延

**問題:**
- 組織ポリシーの変更は**即座に反映されない**
- 最大 **10-15分** かかることがある

**解決策:**
```bash
# 現在のポリシー状態を確認
gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --organization=YOUR_ORG_ID
```

**待機時間:**
- ⏰ 10-15分待ってから再試行

---

### 2️⃣ プロジェクトレベルのポリシー

**問題:**
- 組織レベルで変更しても、**プロジェクトレベル**で制限されている可能性

**確認方法:**
```bash
# プロジェクトレベルのポリシーを確認
gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --project=callog-30758
```

**解決策:**
```bash
# プロジェクトレベルでもポリシーを無効化
gcloud resource-manager org-policies delete \
  iam.disableServiceAccountKeyCreation \
  --project=callog-30758
```

---

### 3️⃣ IAM 権限不足

**問題:**
- Service Account Key を作成する権限がない

**必要な権限:**
- `iam.serviceAccountKeys.create`
- `iam.serviceAccounts.getAccessToken`

**確認方法:**
```bash
# 自分の権限を確認
gcloud projects get-iam-policy callog-30758 \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:user:thp-hoikujouhou@tachanhao.com"
```

**必要なロール:**
- `roles/iam.serviceAccountKeyAdmin` (Service Account Key 管理者)
- または `roles/owner` (オーナー)

**解決策:**
```bash
# 自分に権限を付与 (組織管理者として)
gcloud projects add-iam-policy-binding callog-30758 \
  --member="user:thp-hoikujouhou@tachanhao.com" \
  --role="roles/iam.serviceAccountKeyAdmin"
```

---

### 4️⃣ 継承されたポリシー

**問題:**
- 上位の**フォルダ**レベルでポリシーが設定されている可能性

**確認方法:**
```bash
# 組織の階層を確認
gcloud projects describe callog-30758 --format="value(parent)"

# 出力例:
# organizations/123456789
# または
# folders/987654321
```

**フォルダレベルのポリシーがある場合:**
```bash
# フォルダレベルのポリシーを確認
gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --folder=YOUR_FOLDER_ID

# フォルダレベルで無効化
gcloud resource-manager org-policies delete \
  iam.disableServiceAccountKeyCreation \
  --folder=YOUR_FOLDER_ID
```

---

### 5️⃣ Service Account の状態

**問題:**
- Service Account が無効化されている

**確認方法:**
```bash
# Service Account の状態を確認
gcloud iam service-accounts describe \
  firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

**出力例:**
```yaml
disabled: false  # ← これが true の場合は無効化されている
email: firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
name: projects/callog-30758/serviceAccounts/firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

**解決策 (無効化されている場合):**
```bash
# Service Account を有効化
gcloud iam service-accounts enable \
  firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

---

### 6️⃣ キー作成の試行回数制限

**問題:**
- 短時間に何度も試行すると、一時的にブロックされる

**解決策:**
- ⏰ 10-15分待ってから再試行

---

## 🧪 診断コマンド集

### Step 1: 組織ポリシーの確認

```bash
# プロジェクトを設定
gcloud config set project callog-30758

# 組織 ID を取得
ORG_ID=$(gcloud projects describe callog-30758 --format="value(parent.id)")
echo "Organization ID: $ORG_ID"

# 組織レベルのポリシーを確認
gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --organization=$ORG_ID
```

**期待される出力 (ポリシーが無効化されている場合):**
```
ERROR: (gcloud.resource-manager.org-policies.describe) NOT_FOUND: Requested entity was not found.
```
または
```yaml
constraint: constraints/iam.disableServiceAccountKeyCreation
etag: ...
listPolicy:
  allValues: ALLOW  # ← これが ALLOW なら OK
```

### Step 2: プロジェクトレベルのポリシーを確認

```bash
# プロジェクトレベルのポリシーを確認
gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --project=callog-30758
```

**期待される出力:**
```
ERROR: (gcloud.resource-manager.org-policies.describe) NOT_FOUND: Requested entity was not found.
```
(NOT_FOUND = ポリシーが設定されていない = キー作成が許可されている)

### Step 3: 自分の権限を確認

```bash
# 自分のロールを確認
gcloud projects get-iam-policy callog-30758 \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:user:thp-hoikujouhou@tachanhao.com"
```

**必要なロール:**
- `roles/owner`
- `roles/editor`
- `roles/iam.serviceAccountKeyAdmin`

### Step 4: Service Account の確認

```bash
# Service Account が存在するか確認
gcloud iam service-accounts list --filter="email:firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com"

# Service Account の詳細
gcloud iam service-accounts describe \
  firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

### Step 5: キー作成を試行

```bash
# キー作成を試行
gcloud iam service-accounts keys create ~/firebase-admin-key.json \
  --iam-account=firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

**成功した場合:**
```
created key [abc123def456] of type [json] as [~/firebase-admin-key.json]
```

**失敗した場合のエラーメッセージを確認:**
```
ERROR: (gcloud.iam.service-accounts.keys.create) PERMISSION_DENIED: ...
ERROR: (gcloud.iam.service-accounts.keys.create) FAILED_PRECONDITION: ...
```

---

## 🔧 解決手順 (ステップバイステップ)

### ✅ Step 1: 組織ポリシーをクリア

**組織レベル:**
```bash
# 組織 ID を取得
ORG_ID=$(gcloud projects describe callog-30758 --format="value(parent.id)")

# ポリシーを削除 (無効化)
gcloud resource-manager org-policies delete \
  iam.disableServiceAccountKeyCreation \
  --organization=$ORG_ID
```

**プロジェクトレベル:**
```bash
# プロジェクトレベルでも削除
gcloud resource-manager org-policies delete \
  iam.disableServiceAccountKeyCreation \
  --project=callog-30758
```

### ✅ Step 2: 権限を付与

```bash
# 自分に Service Account Key Admin ロールを付与
gcloud projects add-iam-policy-binding callog-30758 \
  --member="user:thp-hoikujouhou@tachanhao.com" \
  --role="roles/iam.serviceAccountKeyAdmin"
```

### ✅ Step 3: 10-15分待機

⏰ **重要:** ポリシーの伝播には時間がかかります

```bash
# 待機中に現在のステータスを確認
watch -n 30 'gcloud resource-manager org-policies describe \
  iam.disableServiceAccountKeyCreation \
  --project=callog-30758 2>&1'
```

### ✅ Step 4: キー作成を再試行

```bash
# Firebase Console 経由で試行
# https://console.firebase.google.com/project/callog-30758/settings/serviceaccounts/adminsdk

# または gcloud CLI で試行
gcloud iam service-accounts keys create ~/firebase-admin-key.json \
  --iam-account=firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

---

## 🎯 代替案: 新しい Service Account を作成

既存の Service Account がブロックされている場合、**新しい Service Account** を作成できます。

### Step 1: 新しい Service Account を作成

```bash
# 新しい Service Account を作成
gcloud iam service-accounts create callog-api-sa \
  --display-name="Callog API Service Account" \
  --description="Service account for Callog API backend"
```

### Step 2: 必要な権限を付与

```bash
# Firebase Admin 権限
gcloud projects add-iam-policy-binding callog-30758 \
  --member="serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com" \
  --role="roles/firebase.admin"

# Firestore 権限
gcloud projects add-iam-policy-binding callog-30758 \
  --member="serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com" \
  --role="roles/datastore.user"
```

### Step 3: キーを作成

```bash
# 新しい Service Account のキーを作成
gcloud iam service-accounts keys create ~/callog-api-sa-key.json \
  --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
```

**これで成功するはずです！** ✅

---

## 📊 ポリシー確認チェックリスト

確認項目をチェックしてください:

- [ ] 組織レベルのポリシーが削除されているか？
- [ ] プロジェクトレベルのポリシーが削除されているか？
- [ ] フォルダレベルのポリシーがないか？
- [ ] 自分に `iam.serviceAccountKeyAdmin` ロールがあるか？
- [ ] Service Account が有効化されているか？
- [ ] 10-15分待機したか？

---

## 🚀 最も簡単な解決策

### Option 1: 新しい Service Account を作成 ✅

**メリット:**
- ✅ 既存のポリシーの影響を受けない
- ✅ すぐに作成できる
- ✅ クリーンな状態から開始

**コマンド:**
```bash
# 1. 新規作成
gcloud iam service-accounts create callog-api-sa \
  --display-name="Callog API Service Account"

# 2. 権限付与
gcloud projects add-iam-policy-binding callog-30758 \
  --member="serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com" \
  --role="roles/firebase.admin"

# 3. キー作成
gcloud iam service-accounts keys create ~/callog-api-sa-key.json \
  --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
```

### Option 2: ADC を使用 (開発・テスト用) ✅

**メリット:**
- ✅ Service Account Key 不要
- ✅ すぐに使える
- ✅ ローカル開発に最適

**コマンド:**
```bash
gcloud auth application-default login
```

### Option 3: Web API Key を使用 (Vercel 本番環境) ✅

**メリット:**
- ✅ Service Account Key 不要
- ✅ Vercel で動作
- ✅ **既に実装済み**

**ダウンロード:**
```
https://www.genspark.ai/api/files/s/tlJ3yFkA
```

---

## 🎯 推奨事項

### 今すぐ試すべきこと

**1. 新しい Service Account を作成** (最も簡単)

```bash
gcloud iam service-accounts create callog-api-sa \
  --display-name="Callog API Service Account"

gcloud projects add-iam-policy-binding callog-30758 \
  --member="serviceAccount:callog-api-sa@callog-30758.iam.gserviceaccount.com" \
  --role="roles/firebase.admin"

gcloud iam service-accounts keys create ~/callog-api-sa-key.json \
  --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
```

**2. 10-15分待ってから既存の Service Account で再試行**

```bash
# 待機
sleep 900  # 15分

# 再試行
gcloud iam service-accounts keys create ~/firebase-admin-key.json \
  --iam-account=firebase-adminsdk-fbsvc@callog-30758.iam.gserviceaccount.com
```

**3. Web API Key 実装を使用 (Service Account Key 不要)**

- 既に実装済み: `https://www.genspark.ai/api/files/s/tlJ3yFkA`
- すぐに使える
- Vercel で動作

---

## 📞 サポート

どの方法を試しますか？

1. **新しい Service Account を作成** (推奨) ✅
2. **10-15分待ってから再試行**
3. **Web API Key 実装を使用** (Service Account Key 不要) ✅

ご希望の方法をお聞かせください！ 🎯
