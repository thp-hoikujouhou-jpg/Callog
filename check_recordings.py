#!/usr/bin/env python3
"""
Firestore recordings debug script
Check if call recordings are being saved properly
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime

# Initialize Firebase Admin
try:
    cred = credentials.Certificate("/opt/flutter/firebase-admin-sdk.json")
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin initialized")
except Exception as e:
    print(f"❌ Firebase initialization failed: {e}")
    exit(1)

db = firestore.client()

print("\n" + "="*60)
print("📊 CHECKING CALL RECORDINGS IN FIRESTORE")
print("="*60 + "\n")

# Get all recordings
recordings_ref = db.collection('call_recordings')
recordings = recordings_ref.limit(10).stream()

count = 0
for recording in recordings:
    count += 1
    data = recording.to_dict()
    
    print(f"📞 Recording {count}: {recording.id}")
    print(f"   User ID: {data.get('userId', 'N/A')}")
    print(f"   Call Partner: {data.get('callPartner', 'N/A')}")
    print(f"   Duration: {data.get('duration', 0)} seconds")
    print(f"   Timestamp: {data.get('timestamp', 'N/A')}")
    print(f"   Recording URL: {data.get('recordingUrl', 'N/A')[:80]}...")
    print(f"   Transcription Status: {data.get('transcriptionStatus', 'N/A')}")
    
    if data.get('transcription'):
        transcription = data.get('transcription', '')
        print(f"   Transcription: {transcription[:100]}...")
    else:
        print(f"   Transcription: ❌ NOT FOUND")
    
    print()

if count == 0:
    print("⚠️ No recordings found in Firestore")
    print("\n💡 Possible reasons:")
    print("   1. No calls have been recorded yet")
    print("   2. Call recording feature is not working")
    print("   3. Firebase Storage upload is failing")
else:
    print(f"✅ Found {count} recordings in Firestore")
    
print("\n" + "="*60)
