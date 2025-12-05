# 🚀 Callog - クイックリファレンス

## 📱 アプリURL
https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai

## 🔧 Cloud Functions URL

### generateAgoraToken
```
https://generateagoratoken-eyix4hluza-uc.a.run.app
```

### sendPushNotification
```
https://sendpushnotification-eyix4hluza-uc.a.run.app
```

## ⚡ よく使うコマンド

### Cloud Functionsデプロイ
```bash
cd /home/user/Callog
firebase deploy --only functions --token "YOUR_TOKEN"
```

### Flutterアプリビルド
```bash
cd /home/user/Callog
flutter build web --release
```

### サーバー再起動
```bash
# 既存のサーバーを停止
lsof -ti:5060 | xargs -r kill -9

# 新しいサーバーを起動
cd /home/user/Callog
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 > /home/user/server.log 2>&1 &
```

### 完全リビルド&再起動
```bash
cd /home/user/Callog
lsof -ti:5060 | xargs -r kill -9
flutter build web --release
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 > /home/user/server.log 2>&1 &
```

## 📊 ログ確認

### Cloud Functions ログ
```bash
# Firebase Console
https://console.firebase.google.com/project/callog-30758/functions/logs

# または CLI
firebase functions:log --token "YOUR_TOKEN"
```

### Flutter コンソールログ
```
ブラウザのDevTools → Console
```

### サーバーログ
```bash
tail -f /home/user/server.log
```

## 🔍 トラブルシューティング

### CORSエラー
```bash
# 1. ブラウザキャッシュをクリア
Ctrl + Shift + R (強制リフレッシュ)

# 2. Cloud Functionsを確認
curl -X POST https://generateagoratoken-eyix4hluza-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

### 403 Forbidden
```
1. ログアウト → 再ログイン
2. Firebase Auth設定を確認
3. IDトークンが正しく送信されているか確認
```

### 通話が確立しない
```
1. コンソールログでエラーを確認
2. Agora App IDが正しいか確認
3. 相手のFCMトークンが保存されているか確認
```

## 📞 サポート

### Firebase Console
https://console.firebase.google.com/project/callog-30758/overview

### Agora Console
https://console.agora.io/

### ドキュメント
- `/home/user/Callog/DEPLOYMENT_SUCCESS.md` - 詳細な成功レポート
- `/home/user/Callog/FLUTTER_CHANGES_SUMMARY.md` - Flutter変更サマリー
- `/home/user/Callog/ONCALL_VS_ONREQUEST.md` - onCallとonRequestの違い
