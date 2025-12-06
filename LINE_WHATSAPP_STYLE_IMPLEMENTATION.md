# 📱 LINE/WhatsApp方式 着信システム - 完全実装

## 🎯 実装目標

### **LINE/WhatsApp方式の動作:**

| 状態 | 動作 | 理由 |
|---|---|---|
| **アプリ使用中（フォアグラウンド）** | 即座に着信画面 + 着信音 🔔 | ユーザーはアプリを見ているので即座に応答可能 |
| **アプリがバックグラウンド** | プッシュ通知のみ（静かに）🔕 | ユーザーは別のことをしているので邪魔しない |
| **アプリが完全にクローズ** | プッシュ通知のみ（静かに）🔕 | アプリが起動していないので通知のみ |
| **通知オフ + アプリ使用中** | 着信画面 + 着信音 🔔 | 通知設定に関わらずアプリ内で着信表示 |

---

## ✅ 実装完了内容

### **新規サービス:**

1. **`RingtoneService`** (`lib/services/ringtone_service.dart`)
   - 着信音再生/停止
   - ループ再生（応答/拒否まで継続）
   - Web/Mobile両対応

2. **`AppLifecycleService`** (`lib/services/app_lifecycle_service.dart`)
   - アプリの状態監視（Foreground/Background/Closed）
   - WidgetsBindingObserver による自動検出
   - 着信時の動作分岐に使用

### **更新ファイル:**

1. **`push_notification_service.dart`**
   - AppLifecycleServiceと統合
   - フォアグラウンド: 着信画面 + 着信音
   - バックグラウンド: 静かな通知のみ

2. **`incoming_call_screen.dart`**
   - 応答時: 着信音停止
   - 拒否時: 着信音停止
   - 画面破棄時: 着信音停止

3. **`main.dart`**
   - AppLifecycleService初期化

4. **`pubspec.yaml`**
   - audioplayers: 6.1.0 追加

---

## 🎵 着信音の動作

### **着信音が鳴る条件:**
✅ アプリが**フォアグラウンド**（使用中）  
✅ 通話通知を受信  
✅ 着信画面が表示される

### **着信音が鳴らない条件:**
❌ アプリが**バックグラウンド**（別のアプリを使用中）  
❌ アプリが**クローズ**（完全に終了）  
❌ これらの場合は**静かなプッシュ通知のみ**

### **着信音が停止する条件:**
- ✅ 応答ボタンを押した時
- ✅ 拒否ボタンを押した時
- ✅ 30秒タイムアウト
- ✅ 着信画面を閉じた時

---

## 🔔 通知設定との関係

### **通知ON（標準設定）:**
- **フォアグラウンド**: 着信画面 + 着信音 ✅
- **バックグラウンド**: プッシュ通知 ✅
- **クローズ**: プッシュ通知 ✅

### **通知OFF（ユーザーが無効化）:**
- **フォアグラウンド**: 着信画面 + 着信音 ✅ ← **重要！**
- **バックグラウンド**: 通知なし ❌
- **クローズ**: 通知なし ❌

**重要ポイント:** 通知をOFFにしても、**アプリを使用中なら着信画面が表示される**！

---

## 🧪 動作テストシナリオ

### **テスト 1: フォアグラウンド着信**

```
前提: User Aがアプリを使用中
動作: User Bが通話開始
期待結果:
  1. User Aの画面に即座に着信画面が表示される
  2. 着信音（ループ）が鳴り始める
  3. 応答/拒否ボタンが表示される
```

### **テスト 2: バックグラウンド着信**

```
前提: User Aがアプリを開いているが別タブを見ている
動作: User Bが通話開始
期待結果:
  1. デスクトップ通知が静かに表示される
  2. 着信音は鳴らない（静か）
  3. 通知をクリック → 着信画面表示 + 着信音開始
```

### **テスト 3: クローズ状態着信**

```
前提: User Aがアプリを完全にクローズ
動作: User Bが通話開始
期待結果:
  1. デスクトップ通知が静かに表示される
  2. 着信音は鳴らない
  3. 通知をクリック → アプリ起動 → 着信画面表示
```

### **テスト 4: 通知OFF + フォアグラウンド**

```
前提: User Aが通知をOFFに設定 + アプリ使用中
動作: User Bが通話開始
期待結果:
  1. 着信画面が即座に表示される ✅
  2. 着信音が鳴る ✅
  3. 通知設定に関わらず着信を受けられる
```

---

## 🔧 技術的詳細

### **動作フロー図:**

```
[FCM Push Notification]
        ↓
[PushNotificationService._handleForegroundMessage]
        ↓
[AppLifecycleService.isAppInForeground チェック]
        ↓
    ┌───┴───┐
    │       │
Foreground Background
    │       │
    ↓       ↓
着信音ON  着信音OFF
着信画面  通知のみ
```

---

### **コード例:**

```dart
// PushNotificationService._handleForegroundMessage
final isAppVisible = AppLifecycleService().isAppInForeground;

if (isAppVisible) {
  // LINE/WhatsApp behavior: App is visible
  // → Show incoming call screen + Play ringtone
  RingtoneService().playRingtone();
  CallNavigationService().handleCallNotification(data);
} else {
  // App is in background
  // → Show notification only (no ringtone, no call screen)
  _showIncomingCallNotification(message);
}
```

---

## 📱 LINE/WhatsAppとの比較

| 機能 | LINE | WhatsApp | Callog (実装) |
|---|---|---|---|
| フォアグラウンド着信 | 着信画面 + 音 | 着信画面 + 音 | ✅ 着信画面 + 音 |
| バックグラウンド着信 | 通知のみ | 通知のみ | ✅ 通知のみ |
| クローズ状態着信 | 通知のみ | 通知のみ | ✅ 通知のみ |
| 通知OFF時 | アプリ内着信可能 | アプリ内着信可能 | ✅ アプリ内着信可能 |
| 着信音ループ | ✅ | ✅ | ✅ |
| 応答で音停止 | ✅ | ✅ | ✅ |

---

## 🚀 デプロイ & テスト

### **ビルドコマンド:**

```bash
cd /home/user/Callog

# 依存関係インストール
flutter pub get

# Webビルド
flutter build web --release

# サーバー起動
cd build/web
python3 -m http.server 5060 --bind 0.0.0.0 &
```

---

### **Vercel Functions デプロイ:**

```powershell
# Windows PowerShellで実行
cd C:\Users\admin\Downloads\Callog\vercel-api
vercel --prod
```

---

### **テスト手順:**

1. **2つのブラウザでログイン** (User A, User B)

2. **User Aで以下をテスト:**
   - アプリ使用中に通話 → 着信画面 + 音
   - 別タブに切り替え → 静かな通知
   - アプリをクローズ → 静かな通知

3. **User Aでブラウザ通知をOFF:**
   - Chrome設定 → サイト設定 → 通知 → ブロック
   - アプリ使用中に通話 → **着信画面 + 音**（通知OFFでも動作！）

---

## 📊 システムアーキテクチャ

```
┌─────────────────────────┐
│  AppLifecycleService    │
│  (App state tracking)   │
└──────────┬──────────────┘
           ↓
┌──────────────────────────┐
│ PushNotificationService  │
│ (Incoming call handler)  │
└──────────┬───────────────┘
           ↓
    ┌──────┴──────┐
    │             │
Foreground    Background
    │             │
    ↓             ↓
┌────────┐   ┌──────────┐
│Ringtone│   │Silent    │
│Service │   │Push Only │
└───┬────┘   └──────────┘
    ↓
┌─────────────────┐
│IncomingCall     │
│Screen           │
└─────────────────┘
```

---

## 🎉 完成！

**✅ LINE/WhatsApp方式の着信システムが完成しました！**

**主な特徴:**
- ✅ フォアグラウンド: 着信画面 + 着信音
- ✅ バックグラウンド: 静かな通知のみ
- ✅ 通知OFF設定でもアプリ使用中は着信可能
- ✅ 着信音は応答/拒否で自動停止
- ✅ 30秒タイムアウト機能

**これで、LINEやWhatsAppと同じ自然な着信体験を提供できます！** 🚀
