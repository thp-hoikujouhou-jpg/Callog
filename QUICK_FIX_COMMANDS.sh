#!/bin/bash
# Cloud Functions 削除と再デプロイの完全手順

echo "🔧 Cloud Functions デプロイエラー修正スクリプト"
echo ""
echo "このスクリプトは以下を実行します:"
echo "1. 既存のCloud Functions (onCall版) を削除"
echo "2. 新しいCloud Functions (onRequest版) をデプロイ"
echo ""

# プロジェクトディレクトリに移動
cd /home/user/Callog

echo "📍 現在のディレクトリ: $(pwd)"
echo ""

# ステップ1: Firebase にログイン
echo "🔐 ステップ1: Firebase にログイン"
echo "以下のコマンドを実行してください:"
echo ""
echo "  firebase login"
echo ""
read -p "ログイン完了後、Enterキーを押してください..." wait_login
echo ""

# ステップ2: 既存の関数を削除
echo "🗑️ ステップ2: 既存の関数を削除"
echo ""

echo "generateAgoraToken を削除します..."
firebase functions:delete generateAgoraToken --region us-central1
echo ""

echo "sendPushNotification を削除します..."
firebase functions:delete sendPushNotification --region us-central1
echo ""

# ステップ3: 削除の確認
echo "✅ ステップ3: 削除の確認"
echo "現在の関数リスト:"
firebase functions:list
echo ""

# ステップ4: 新しい関数をデプロイ
echo "🚀 ステップ4: 新しい関数をデプロイ"
firebase deploy --only functions
echo ""

# ステップ5: デプロイ結果の確認
echo "✅ ステップ5: デプロイ結果の確認"
echo "デプロイされた関数リスト:"
firebase functions:list
echo ""

echo "🎉 完了!"
echo ""
echo "次のステップ:"
echo "1. Flutterアプリをリロード (Ctrl + Shift + R)"
echo "2. 通話機能をテスト"
echo "3. コンソールでCORSエラーが消えたか確認"
