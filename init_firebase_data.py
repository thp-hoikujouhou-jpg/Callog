#!/usr/bin/env python3
"""
Initialize Callog Firebase Database with sample data
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import random

# Initialize Firebase Admin SDK
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')

try:
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized")
except ValueError:
    print("⚠️ Firebase already initialized")

db = firestore.client()

def check_firestore_database():
    """Check if Firestore database exists"""
    try:
        # Try to read from Firestore
        db.collection('_test_').limit(1).get()
        print("✅ Firestore Database exists and is accessible")
        return True
    except Exception as e:
        print(f"❌ Firestore Database not accessible: {e}")
        return False

def create_sample_users():
    """Create sample user profiles"""
    print("\n📝 Creating sample users...")
    
    users = [
        {
            'uid': 'demo_user_001',
            'email': 'alice@example.com',
            'displayName': 'Alice Johnson',
            'username': 'alice_j',
            'bio': 'Software developer passionate about Flutter and Firebase',
            'profileImageUrl': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alice',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
        {
            'uid': 'demo_user_002',
            'email': 'bob@example.com',
            'displayName': 'Bob Smith',
            'username': 'bob_smith',
            'bio': 'Tech enthusiast and mobile app developer',
            'profileImageUrl': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Bob',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
        {
            'uid': 'demo_user_003',
            'email': 'charlie@example.com',
            'displayName': 'Charlie Davis',
            'username': 'charlie_d',
            'bio': 'Designer and creative thinker',
            'profileImageUrl': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Charlie',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
    ]
    
    for user in users:
        try:
            db.collection('users').document(user['uid']).set(user)
            print(f"  ✅ Created user: {user['displayName']}")
        except Exception as e:
            print(f"  ❌ Error creating user {user['displayName']}: {e}")

def create_sample_chats():
    """Create sample chat messages"""
    print("\n💬 Creating sample chat messages...")
    
    chats = [
        {
            'chatId': 'chat_001',
            'participants': ['demo_user_001', 'demo_user_002'],
            'lastMessage': 'Hey! How are you?',
            'lastMessageTime': firestore.SERVER_TIMESTAMP,
            'createdAt': firestore.SERVER_TIMESTAMP,
        },
        {
            'chatId': 'chat_002',
            'participants': ['demo_user_001', 'demo_user_003'],
            'lastMessage': 'Let\'s schedule a call tomorrow',
            'lastMessageTime': firestore.SERVER_TIMESTAMP,
            'createdAt': firestore.SERVER_TIMESTAMP,
        },
    ]
    
    for chat in chats:
        try:
            db.collection('chats').document(chat['chatId']).set(chat)
            print(f"  ✅ Created chat: {chat['chatId']}")
        except Exception as e:
            print(f"  ❌ Error creating chat: {e}")

def create_sample_meeting_notes():
    """Create sample meeting notes"""
    print("\n📅 Creating sample meeting notes...")
    
    notes = [
        {
            'noteId': 'note_001',
            'userId': 'demo_user_001',
            'title': 'Project Planning Meeting',
            'content': 'Discussed Q1 objectives and milestones',
            'date': datetime.now().isoformat(),
            'location': 'Conference Room A',
            'participants': ['Alice Johnson', 'Bob Smith'],
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
        {
            'noteId': 'note_002',
            'userId': 'demo_user_001',
            'title': 'Client Call Follow-up',
            'content': 'Review requirements and timeline with client',
            'date': (datetime.now() + timedelta(days=2)).isoformat(),
            'location': 'Video Call',
            'participants': ['Alice Johnson', 'Charlie Davis'],
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
    ]
    
    for note in notes:
        try:
            db.collection('meeting_notes').document(note['noteId']).set(note)
            print(f"  ✅ Created meeting note: {note['title']}")
        except Exception as e:
            print(f"  ❌ Error creating meeting note: {e}")

def main():
    print("🔥 Callog Firebase Database Initialization")
    print("=" * 50)
    
    # Check if Firestore database exists
    if not check_firestore_database():
        print("\n❌ Please create Firestore Database first:")
        print("   https://console.firebase.google.com/project/callog-30758/firestore")
        return
    
    # Create sample data
    create_sample_users()
    create_sample_chats()
    create_sample_meeting_notes()
    
    print("\n" + "=" * 50)
    print("✅ Firebase database initialization complete!")
    print("\n📊 Summary:")
    print("   - 3 sample users created")
    print("   - 2 sample chats created")
    print("   - 2 sample meeting notes created")
    print("\n🌐 View data in Firebase Console:")
    print("   https://console.firebase.google.com/project/callog-30758/firestore")

if __name__ == '__main__':
    main()
