# 🔥 FCM Push Notifications - No Firebase Admin SDK Required

## 📦 Overview

This implementation sends FCM browser notifications **WITHOUT** Firebase Admin SDK:

✅ **No Firebase Admin SDK**
✅ **No Service Account Key**
✅ **No Firestore Authentication**
✅ **Only Web API Key required**

---

## 🎯 How It Works

### Architecture

```
Flutter App (Client)
    ↓ (1) Get peer's FCM token from Firestore
    ↓ (2) Send FCM token + call data
Vercel API (sendPushNotification.js)
    ↓ (3) Call FCM Legacy API with Web API Key
FCM (Firebase Cloud Messaging)
    ↓ (4) Send browser notification
User's Browser
    ↓ (5) Display desktop notification
```

### Key Differences from Previous Versions

| Item | Old Version | **New Version (Current)** |
|------|-------------|---------------------------|
| **FCM Token Source** | Vercel reads from Firestore | Flutter sends directly |
| **Firestore Access** | Required on server | Not required on server |
| **Firebase Admin SDK** | Required | **Not required** ✅ |
| **Authentication** | Service Account Key | Web API Key only ✅ |
| **CORS Issues** | Possible | None ✅ |

---

## 🚀 Setup Steps

### Step 1: Download Latest Project

**Download URL:**
```
https://www.genspark.ai/api/files/s/tlJ3yFkA
```

**File name:** `callog-api-v2-fcm-no-admin-sdk.tar.gz`
**Size:** ~20 KB

### Step 2: Extract and Deploy

```bash
# 1. Delete old project
cd C:\Users\admin\Downloads
rmdir /s /q callog-api-v2

# 2. Extract new project
# (Extract the downloaded tar.gz file to C:\Users\admin\Downloads\callog-api-v2)

# 3. Deploy to Vercel
cd C:\Users\admin\Downloads\callog-api-v2
vercel --prod
```

When prompted:
- **Set up and deploy?** → `Y`
- **Which scope?** → Select your account
- **Link to existing project?** → `Y`
- **Project name?** → `callog-api-v2`
- **Override settings?** → `N`

### Step 3: Verify Environment Variables

Open Vercel settings:
```
https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables
```

**Required variables:**

1. ✅ `FIREBASE_PROJECT_ID` = `callog-30758`
2. ✅ `FIREBASE_WEB_API_KEY` = `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA`
3. ✅ `AGORA_APP_ID` = `d1a8161eb70448d89eea1722bc169c92`

**NOT required:**
- ❌ `FIREBASE_SERVICE_ACCOUNT` (not needed!)
- ❌ `FCM_SERVER_KEY` (not needed!)

---

## 🧪 Testing

### Test 1: API Endpoint Test

**PowerShell:**
```powershell
$body = @{
    data = @{
        fcmToken = "YOUR_FCM_TOKEN_HERE"
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

**Expected Response:**
```json
{
  "data": {
    "success": true,
    "messageId": "0:1234567890123456%abc123",
    "message": "Push notification sent successfully via FCM",
    "method": "FCM Legacy API",
    "timestamp": 1234567890123
  }
}
```

### Test 2: Browser Notification Test

**2 Browser Tabs:**

**Tab 1 (Caller - User A):**
1. Open: `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai`
2. Login as User A
3. Select a friend (User B)
4. Start audio or video call

**Tab 2 (Receiver - User B):**
1. Open: `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai`
2. Login as User B
3. **Switch to a different tab** (e.g., Gmail, YouTube)
4. **Wait for desktop notification** 🔔

**Expected Behavior:**

Even though Tab 2 is in the background, User B should see:
```
┌──────────────────────────────────┐
│ 🔔 Callog                        │
│                                  │
│ 📞 [User A Name]から音声通話着信  │
│                                  │
│ [クリックして応答]                 │
└──────────────────────────────────┘
```

**Console Logs (Tab 1 - Caller):**
```
[Push] 📤 Sending notification via Vercel API
[Push] 🔍 Fetching FCM token for peer: user_b_id
[Push] ✅ Peer FCM token found: d5A3-3dQg-2wegmmx9CN...
[Push] ✅ Notification sent successfully!
```

---

## 🔧 Troubleshooting

### Error: "FIREBASE_WEB_API_KEY not configured"

**Cause:** Environment variable not set in Vercel.

**Solution:**
1. Go to: `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2/settings/environment-variables`
2. Add `FIREBASE_WEB_API_KEY` = `AIzaSyADm_scTXk7oTh39uFtKEuDlnqvP4OqoqA`
3. Check all environments (Production, Preview, Development)
4. Redeploy: `vercel --prod`

### Error: "Peer has no FCM token registered"

**Cause:** User B has not logged in yet, or FCM token was not saved.

**Solution:**
1. User B should login to Callog
2. Check browser console: `[Push] ✅ FCM token saved to Firestore successfully`
3. Verify Firestore: `users/{userId}/fcmToken` field exists

### Error: "InvalidRegistration"

**Cause:** FCM token is expired or invalid.

**Solution:**
1. User B should re-login to Callog
2. New FCM token will be generated and saved
3. Try the call again

### No Desktop Notification Appears

**Possible causes:**

1. **Browser notification permission not granted**
   - Check browser settings: `chrome://settings/content/notifications`
   - Ensure Callog is allowed

2. **Service Worker not registered**
   - Open: `chrome://serviceworker-internals/`
   - Check if Callog's service worker is active

3. **FCM token not saved**
   - Check console: `[Push] ✅ FCM token saved to Firestore successfully`
   - If missing, logout and login again

4. **Vercel API not deployed**
   - Verify deployment: `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2`
   - Check deployment status is "Ready"

---

## 📋 Code Structure

### Vercel API: `/api/sendPushNotification.js`

```javascript
// Key features:
// - No Firebase Admin SDK
// - No Firestore access
// - FCM token received from Flutter directly
// - Uses FCM Legacy API with Web API Key
// - Simple and straightforward
```

### Flutter: `/lib/services/push_notification_service.dart`

```dart
// Key features:
// - Fetches peer's FCM token from Firestore
// - Sends FCM token directly to Vercel API
// - No server-side Firestore access needed
// - Better error handling
```

---

## 🎯 Summary

### What Changed

**Before (Old Version):**
1. Flutter sends `peerId` to Vercel API
2. Vercel API uses Firebase Admin SDK to access Firestore
3. Get FCM token from Firestore
4. Send FCM notification
**Problem:** Firebase Admin SDK requires Service Account Key (organizational policy issue)

**After (New Version):**
1. Flutter fetches peer's FCM token from Firestore directly
2. Flutter sends `fcmToken` + call data to Vercel API
3. Vercel API uses FCM Legacy API (Web API Key)
4. Send FCM notification
**Solution:** No Firebase Admin SDK needed! ✅

### Benefits

✅ **No organizational policy issues**
✅ **No service account key required**
✅ **Simpler server-side code**
✅ **Direct FCM API call**
✅ **Better error messages**
✅ **Easier to maintain**

---

## 📞 Support

If you encounter issues:

1. **Check Vercel deployment logs:**
   `https://vercel.com/thp-hoikujouhou-tachanhao164s-projects/callog-api-v2`

2. **Check browser console logs:**
   - Press `F12` → Console tab
   - Look for `[Push]` messages

3. **Verify Firestore data:**
   - Open: `https://console.firebase.google.com/project/callog-30758/firestore`
   - Check `users/{userId}/fcmToken` exists

4. **Test API directly:**
   - Use PowerShell command above
   - Check response for errors

---

## ✅ Checklist

Before testing, make sure:

- [ ] Downloaded latest project (`https://www.genspark.ai/api/files/s/tlJ3yFkA`)
- [ ] Extracted to `C:\Users\admin\Downloads\callog-api-v2`
- [ ] Deployed with `vercel --prod`
- [ ] Verified `FIREBASE_WEB_API_KEY` is set in Vercel
- [ ] Opened Flutter app in 2 browser tabs
- [ ] Both users logged in successfully
- [ ] Browser notification permission granted
- [ ] Ready to test! 🚀

---

**Estimated Setup Time:** 5-10 minutes

**Next Steps:**
1. Download and deploy the new Vercel project
2. Test with 2 browser tabs
3. Report results! 📊
