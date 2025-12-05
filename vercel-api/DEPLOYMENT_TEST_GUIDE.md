# 🔧 Vercel Deployment Test Guide

## 現在の状況
- ✅ Vercelデプロイメント成功
- ✅ 本番URL: `https://callog-api-v2.vercel.app`
- ❌ API エラー: `Cannot read properties of undefined (reading 'data')`

## 問題の原因
**Vercel環境変数が設定されていない可能性が高い**

エラーメッセージから推測:
- `req.body` が `undefined` → Vercelのボディパーサーが動いていない可能性
- または環境変数 `AGORA_APP_CERTIFICATE` が未設定でコード内でエラー発生

---

## ✅ 解決手順

### **Step 1: Vercel環境変数を設定**

以下のURLで環境変数を設定:
```
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
```

**必須の3つの環境変数:**

| Key | Value | Environments | Sensitive |
|-----|-------|--------------|-----------|
| `FIREBASE_PROJECT_ID` | `callog-30758` | ✅ Production, Preview, Development | ❌ |
| `AGORA_APP_ID` | `d1a8161eb70448d89eea1722bc169c92` | ✅ Production, Preview, Development | ❌ |
| `AGORA_APP_CERTIFICATE` | (Agora Consoleから取得) | ✅ Production, Preview, Development | ✅ |

**重要:** 環境変数を追加したら、必ず再デプロイが必要です!

---

### **Step 2: 再デプロイ**

環境変数設定後、以下のコマンドで再デプロイ:

```bash
cd C:\Users\admin\Downloads\callog-api-v2
vercel --prod
```

---

### **Step 3: API テスト (Windows Command Prompt)**

**正しいコマンド (1行で実行):**

```bash
curl -X POST https://callog-api-v2.vercel.app/api/generateAgoraToken -H "Content-Type: application/json" -d "{\"data\":{\"channelName\":\"test\",\"uid\":0,\"role\":\"publisher\"}}"
```

**期待される結果:**
```json
{
  "data": {
    "token": "007eJxT...",
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test",
    "uid": 0,
    "expiresAt": 1234567890
  }
}
```

---

### **Step 4: PowerShell 代替コマンド (推奨)**

Windows PowerShellを使う方が安全です:

```powershell
$body = @{
    data = @{
        channelName = "test"
        uid = 0
        role = "publisher"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://callog-api-v2.vercel.app/api/generateAgoraToken" -Method Post -ContentType "application/json" -Body $body
```

---

## 🔍 トラブルシューティング

### **エラー 1: `Cannot read properties of undefined`**
**原因:** 環境変数未設定、またはリクエストボディが正しく解析されていない

**解決策:**
1. Vercelダッシュボードで環境変数を確認
2. 再デプロイ (`vercel --prod`)
3. Vercelデプロイメントログを確認

---

### **エラー 2: `Channel name is required`**
**原因:** リクエストボディの形式が間違っている

**正しい形式:**
```json
{
  "data": {
    "channelName": "test",
    "uid": 0,
    "role": "publisher"
  }
}
```

---

### **エラー 3: `App Certificate not configured`**
**原因:** `AGORA_APP_CERTIFICATE` 環境変数が未設定

**解決策:**
1. Agora Console (`https://console.agora.io/`) でアプリ証明書を取得
2. Vercel環境変数に追加
3. 再デプロイ

---

## 📋 チェックリスト

デプロイメント前の確認事項:

- [ ] Vercel環境変数 `FIREBASE_PROJECT_ID` を設定
- [ ] Vercel環境変数 `AGORA_APP_ID` を設定
- [ ] Vercel環境変数 `AGORA_APP_CERTIFICATE` を設定 (Sensitiveを有効化)
- [ ] 環境変数設定後、`vercel --prod` で再デプロイ
- [ ] Vercelダッシュボードでデプロイメントステータスが `Ready` になっている
- [ ] curlコマンドでAPIテスト成功

---

## 🎯 次のステップ

1. **Vercel環境変数を設定** (上記Step 1)
2. **再デプロイ** (`vercel --prod`)
3. **APIテスト** (curlまたはPowerShell)
4. **結果を報告**:
   - ✅ 成功: トークンが正しく生成された
   - ❌ エラー: エラーメッセージを共有

成功すれば、FlutterアプリのURL更新に進みます! 🚀
