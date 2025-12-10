#!/usr/bin/env python3
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("/opt/flutter/firebase-admin-sdk.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Get the successful recording
doc = db.collection('call_recordings').document('M6RMZiOuYZqPIQ04JYeR').get()
if doc.exists:
    data = doc.to_dict()
    print("✅ Successful Recording Details:")
    print(f"   Recording URL: {data.get('recordingUrl', 'N/A')}")
    print(f"   Duration: {data.get('duration')} seconds")
    print(f"   Transcription: {data.get('transcription', 'N/A')}")
    print(f"   Status: {data.get('transcriptionStatus')}")

# Get a failed recording
print("\n❌ Failed Recording Details:")
doc2 = db.collection('call_recordings').document('7INI8OnuTZg6zBHXRAkx').get()
if doc2.exists:
    data2 = doc2.to_dict()
    print(f"   Recording URL: {data2.get('recordingUrl', 'N/A')}")
    print(f"   Duration: {data2.get('duration')} seconds")
    print(f"   Status: {data2.get('transcriptionStatus')}")
    if data2.get('transcriptionError'):
        print(f"   Error: {data2.get('transcriptionError')}")
