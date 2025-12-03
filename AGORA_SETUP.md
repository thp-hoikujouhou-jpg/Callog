# Agora通話機能セットアップガイド

## 🚨 エラー -17 (INVALID_APP_ID) の解決方法

音声・ビデオ通話で「AgoraRtcException(-17, null)」エラーが発生する場合、以下の手順で解決できます。

---

## 📋 必須手順: Agora App IDの取得と設定

### ステップ1: Agoraアカウントの作成

1. **Agora Console** にアクセス
   - URL: https://console.agora.io/
   - 「Sign Up」ボタンをクリック
   - メールアドレスとパスワードでアカウント作成

### ステップ2: プロジェクトの作成

1. Agora Consoleにログイン
2. 「Project Management」をクリック
3. 「Create」ボタンをクリック
4. プロジェクト名を入力（例: "Callog"）
5. 「Authentication mechanism」で以下を選択：
   - **テスト用**: "App ID" を選択
   - **本番用**: "Token" を選択（推奨）
6. 「Submit」をクリック

### ステップ3: App IDの取得

1. 作成したプロジェクトの行にある「👁️」アイコンをクリック
2. **App ID** をコピー（32文字の16進数文字列）
   - 例: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`

### ステップ4: Flutterアプリへの設定

#### 方法1: 設定ファイルを使用（推奨）

1. ファイルを開く: `lib/config/agora_config.dart`
2. `appId` の値を更新:

```dart
class AgoraConfig {
  // コピーしたApp IDをここに貼り付け
  static const String appId = 'YOUR_APP_ID_HERE';
}
```

3. ファイルを保存

#### 方法2: サービスファイルを直接編集

以下のファイルのApp IDを更新:

1. `lib/services/agora_voice_call_service.dart`
2. `lib/services/agora_video_call_service.dart`

```dart
static const String appId = 'YOUR_APP_ID_HERE';
```

### ステップ5: アプリの再ビルド

```bash
# Android APKをビルド
flutter clean
flutter pub get
flutter build apk --release

# または開発モード
flutter run
```

---

## 🔍 トラブルシューティング

### エラー: AgoraRtcException(-17, null)

**原因:**
- App IDが無効または期限切れ
- App IDの形式が正しくない
- Agoraプロジェクトが無効化されている
- インターネット接続がない

**解決方法:**

1. **App IDの確認**
   ```dart
   // 正しい形式
   'd1a8161eb70448d89eea1722bc169c92'  // ✅ 32文字の16進数
   
   // 間違った形式
   ''                                    // ❌ 空文字
   'test-app-id'                        // ❌ 16進数ではない
   'd1a8161eb70448'                     // ❌ 32文字未満
   ```

2. **Agoraプロジェクトの状態確認**
   - Agora Consoleにログイン
   - プロジェクトのステータスが「Active」であることを確認
   - 無効化されている場合は、「Enable」をクリック

3. **新しいApp IDの生成**
   - 問題が解決しない場合は、新しいプロジェクトを作成
   - 新しいApp IDを取得して設定

4. **インターネット接続の確認**
   - デバイスがインターネットに接続されていることを確認
   - ファイアウォールがAgoraのサーバーをブロックしていないか確認

---

## 📱 Android権限の確認

`android/app/src/main/AndroidManifest.xml` に以下の権限が含まれていることを確認:

```xml
<!-- 音声通話用 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

<!-- ビデオ通話用 -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- オプション -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

---

## 🔐 本番環境でのToken使用（推奨）

テスト環境ではApp IDのみで動作しますが、本番環境では**Token認証**を使用することを強く推奨します。

### Tokenの生成方法

1. Agora Consoleで「Token」タブを開く
2. Channel NameとUser IDを入力
3. 「Generate Token」をクリック
4. 生成されたTokenをアプリに設定

```dart
// Token付きで通話に参加
await agoraService.joinChannel(
  'channel_name',
  token: 'YOUR_TOKEN_HERE',
);
```

---

## 📚 参考リンク

- [Agora Console](https://console.agora.io/)
- [Agora Documentation](https://docs.agora.io/)
- [Flutter SDK Guide](https://docs.agora.io/en/video-calling/get-started/get-started-sdk?platform=flutter)
- [Error Code Reference](https://docs.agora.io/en/video-calling/reference/error-codes)

---

## ❓ よくある質問

**Q: App IDはどこで確認できますか？**
A: Agora Console > Project Management > 該当プロジェクトの「👁️」アイコンをクリック

**Q: 無料で使えますか？**
A: はい。Agoraは毎月10,000分まで無料で使用できます。

**Q: Web版とAndroid版で異なるApp IDが必要ですか？**
A: いいえ。同じApp IDをすべてのプラットフォームで使用できます。

**Q: エラー -17が解決しません**
A: 以下を確認してください：
1. App IDが32文字の16進数文字列であること
2. Agoraプロジェクトがアクティブであること
3. インターネット接続が有効であること
4. 最新のagora_rtc_engineパッケージを使用していること

---

## 🆘 サポート

問題が解決しない場合は、以下の情報を含めてお問い合わせください：

- エラーメッセージ全文
- 使用しているApp ID（最初の8文字のみ）
- プラットフォーム（Android/iOS/Web）
- Flutter SDK バージョン
- agora_rtc_engine パッケージバージョン
