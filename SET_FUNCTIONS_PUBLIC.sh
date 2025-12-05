#!/bin/bash
# Cloud Functions を公開するスクリプト

echo "🔓 Cloud Functions を公開設定します"
echo ""
echo "プロジェクト: callog-30758"
echo "リージョン: us-central1"
echo ""

# 方法1: gcloud コマンドを試す
echo "📍 方法1: gcloud CLI を使用"
echo ""

if command -v gcloud &> /dev/null; then
    echo "✅ gcloud CLI が見つかりました"
    echo ""
    
    # ログイン確認
    echo "🔐 Google Cloud にログインします..."
    gcloud auth login
    echo ""
    
    # プロジェクト設定
    echo "📌 プロジェクトを設定します..."
    gcloud config set project callog-30758
    echo ""
    
    # generateAgoraToken を公開
    echo "🔓 generateAgoraToken を公開中..."
    gcloud functions add-iam-policy-binding generateAgoraToken \
      --region=us-central1 \
      --member=allUsers \
      --role=roles/cloudfunctions.invoker \
      --project=callog-30758
    echo ""
    
    # sendPushNotification を公開
    echo "🔓 sendPushNotification を公開中..."
    gcloud functions add-iam-policy-binding sendPushNotification \
      --region=us-central1 \
      --member=allUsers \
      --role=roles/cloudfunctions.invoker \
      --project=callog-30758
    echo ""
    
    echo "✅ 完了!"
    echo ""
    echo "🧪 テストコマンド:"
    echo "curl -X POST https://us-central1-callog-30758.cloudfunctions.net/generateAgoraToken \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"data\":{\"channelName\":\"test\",\"uid\":0,\"role\":\"publisher\"}}'"
    
else
    echo "❌ gcloud CLI が見つかりません"
    echo ""
    echo "📋 代替方法: Firebase Console を使用してください"
    echo ""
    echo "1. https://console.firebase.google.com/ を開く"
    echo "2. Callog プロジェクトを選択"
    echo "3. Functions → generateAgoraToken → ︙ → Permissions"
    echo "4. ADD PRINCIPAL をクリック"
    echo "5. New principals: allUsers"
    echo "6. Role: Cloud Functions Invoker"
    echo "7. SAVE"
    echo ""
    echo "8. sendPushNotification でも同じ手順を繰り返す"
    echo ""
fi
