# iOS セットアップガイド

## 必要な追加ファイル

### 1. Info.plist への追加（ios/Runner/Info.plist）

既存の `<dict>` タグ内に以下を追加：

```xml
<!-- カメラ権限 -->
<key>NSCameraUsageDescription</key>
<string>ビデオ通話でカメラを使用します</string>

<!-- マイク権限 -->
<key>NSMicrophoneUsageDescription</key>
<string>音声通話とビデオ通話でマイクを使用します</string>

<!-- フォトライブラリ権限 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>プロフィール写真を選択するために使用します</string>

<!-- プッシュ通知とVoIP -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>voip</string>
    <string>audio</string>
</array>

<!-- Agora用 -->
<key>io.flutter.embedded_views_preview</key>
<true/>
```

### 2. Podfile の更新（ios/Podfile）

既存の Podfile を以下に置き換え：

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Agora 用の設定
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

### 3. Firebase iOS 設定

1. **Firebase Console** (https://console.firebase.google.com/)
   - プロジェクトを選択
   - iOS アプリを追加
   - Bundle ID: `com.callog.mobile_use`
   - `GoogleService-Info.plist` をダウンロード

2. **ファイル配置**
   ```bash
   # GoogleService-Info.plist を ios/Runner/ にコピー
   cp GoogleService-Info.plist ios/Runner/
   ```

### 4. Apple Developer 設定

#### A. App ID 作成
1. **Apple Developer Portal**: https://developer.apple.com/account/
2. Certificates, IDs & Profiles → Identifiers
3. 新規 App ID を作成
   - Description: `Callog`
   - Bundle ID: `com.callog.mobile_use`
   - Capabilities:
     - ✅ Push Notifications
     - ✅ Background Modes
     - ✅ Sign In with Apple (optional)

#### B. Provisioning Profile 作成
1. Certificates, IDs & Profiles → Profiles
2. 新規 Provisioning Profile
   - Type: App Store Distribution
   - App ID: 上で作成した App ID
   - Certificate: 開発証明書を選択

#### C. Push Notification 証明書
1. Certificates, IDs & Profiles → Keys
2. 新規 Key を作成
   - Key Name: `Callog Push Notifications`
   - ✅ Apple Push Notifications service (APNs)
3. `.p8` ファイルをダウンロード
4. Firebase Console → Project Settings → Cloud Messaging
   - iOS app configuration → APNs Authentication Key
   - `.p8` ファイルをアップロード

### 5. Xcode での設定

```bash
# Mac で実行
cd Callog/ios
open Runner.xcworkspace  # Xcode で開く
```

Xcode で：
1. **Signing & Capabilities**
   - Team を選択
   - Automatically manage signing を有効化
   - Bundle Identifier: `com.callog.mobile_use`

2. **Capabilities 追加**
   - ✅ Push Notifications
   - ✅ Background Modes
     - ✅ Audio, AirPlay, and Picture in Picture
     - ✅ Voice over IP
     - ✅ Background fetch
     - ✅ Remote notifications

### 6. ビルドコマンド

#### シミュレータで実行（テスト用）
```bash
flutter run -d ios
```

#### 実機用ビルド
```bash
# デバッグ版（開発用）
flutter build ios --debug

# リリース版（配布用）
flutter build ios --release

# IPA ファイル生成（App Store提出用）
flutter build ipa --release
```

#### App Store 提出
```bash
# Xcode で Archive
# Product → Archive → Distribute App → App Store Connect
```

### 7. TestFlight 配布

1. **App Store Connect** (https://appstoreconnect.apple.com/)
2. マイ App → 新規 App
   - プラットフォーム: iOS
   - 名前: Callog
   - Bundle ID: com.callog.mobile_use
3. TestFlight → 内部テスト
   - ビルドをアップロード
   - テスターを招待

## トラブルシューティング

### エラー: `pod install` が失敗
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### エラー: 署名エラー
- Xcode で Team を確認
- Provisioning Profile を再生成
- `Clean Build Folder` (Cmd+Shift+K)

### エラー: Firebase 設定エラー
- `GoogleService-Info.plist` が正しい場所にあるか確認
- Bundle ID が一致しているか確認

## まとめ

1. ✅ `Info.plist` に権限を追加
2. ✅ `Podfile` を更新
3. ✅ Firebase iOS アプリを追加
4. ✅ Apple Developer で App ID 作成
5. ✅ Xcode で署名設定
6. ✅ `flutter build ipa` でビルド
7. ✅ TestFlight または App Store で配布

**所要時間**: 約 2-3 時間（Apple Developer アカウント設定含む）
