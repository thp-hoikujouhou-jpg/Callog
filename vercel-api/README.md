# Callog API - Vercel Functions

Simplified Vercel Functions for Callog app - Agora token generation without Firebase Admin SDK.

## Structure

```
callog-api-v2/
├── api/
│   ├── generateAgoraToken.js    # Agora RTC token generation
│   └── sendPushNotification.js  # Placeholder (disabled)
├── package.json
├── vercel.json
└── README.md
```

## Environment Variables (Required)

Set these in Vercel Dashboard:

1. `FIREBASE_PROJECT_ID` = `callog-30758` (optional, for reference)
2. `AGORA_APP_ID` = `d1a8161eb70448d89eea1722bc169c92`
3. `AGORA_APP_CERTIFICATE` = (from Agora Console)

## Deployment

```bash
# Install Vercel CLI (if not installed)
npm install -g vercel

# Login
vercel login

# Deploy to production
vercel --prod
```

## API Endpoints

### Generate Agora Token

**POST** `/api/generateAgoraToken`

Request:
```json
{
  "data": {
    "channelName": "test-channel",
    "uid": 0,
    "role": "publisher"
  }
}
```

Response:
```json
{
  "data": {
    "token": "007eJxT...",
    "appId": "d1a8161eb70448d89eea1722bc169c92",
    "channelName": "test-channel",
    "uid": 0,
    "expiresAt": 1234567890
  }
}
```

### Send Push Notification (Placeholder)

**POST** `/api/sendPushNotification`

Returns success message (feature disabled).

## Testing

```bash
curl -X POST https://your-deployment.vercel.app/api/generateAgoraToken \
  -H "Content-Type: application/json" \
  -d '{"data":{"channelName":"test","uid":0,"role":"publisher"}}'
```

## Features

- ✅ Agora RTC token generation
- ✅ CORS enabled
- ✅ No Firebase Admin SDK required
- ✅ Minimal dependencies
- ⚠️ Push notifications disabled

## License

MIT
