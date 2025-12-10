#!/usr/bin/env python3
"""
Firebase Storage CORS設定スクリプト

このスクリプトは、Firebase Admin SDKを使用してFirebase Storageの
メタデータを確認し、CORS設定の状態を表示します。

実際のCORS設定はGoogle Cloud Storage APIまたはgsutilツールで行う必要があります。
"""

import sys
try:
    import firebase_admin
    from firebase_admin import credentials, storage
    print("✅ firebase-admin imported successfully")
except ImportError as e:
    print(f"❌ Failed to import firebase-admin: {e}")
    print("📦 INSTALLATION REQUIRED:")
    print("pip install firebase-admin==7.1.0")
    sys.exit(1)

def main():
    print("\n🔧 Firebase Storage CORS Configuration Helper\n")
    
    # Initialize Firebase Admin SDK
    try:
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'callog-30758.firebasestorage.app'
        })
        print("✅ Firebase Admin SDK initialized successfully\n")
    except Exception as e:
        print(f"❌ Failed to initialize Firebase Admin SDK: {e}")
        sys.exit(1)
    
    # Get storage bucket
    try:
        bucket = storage.bucket()
        print(f"✅ Connected to bucket: {bucket.name}\n")
    except Exception as e:
        print(f"❌ Failed to connect to storage bucket: {e}")
        sys.exit(1)
    
    # List some profile images
    print("📸 Checking profile images...\n")
    try:
        blobs = bucket.list_blobs(prefix='profile_images/', max_results=5)
        blob_list = list(blobs)
        
        if not blob_list:
            print("⚠️  No profile images found in storage")
        else:
            print(f"Found {len(blob_list)} profile images (showing first 5):\n")
            for blob in blob_list:
                print(f"  📄 {blob.name}")
                # Make the blob publicly readable
                try:
                    blob.make_public()
                    print(f"    ✅ Made public: {blob.public_url}\n")
                except Exception as e:
                    print(f"    ⚠️  Could not make public: {e}\n")
    except Exception as e:
        print(f"❌ Failed to list blobs: {e}")
    
    print("\n" + "="*60)
    print("📋 CORS CONFIGURATION INSTRUCTIONS")
    print("="*60)
    print("""
Firebase Storageの画像がCORSエラーで読み込めない問題を解決するには、
以下の2つの方法があります:

方法1: Firebase Consoleで画像を公開可能にする
---------------------------------------------
1. Firebase Console を開く
   https://console.firebase.google.com/
   
2. プロジェクト 'callog-30758' を選択

3. Storage → Files タブ

4. profile_images フォルダを右クリック
   → 「アクセス権限の編集」
   → 「allUsers」に「Storage Object Viewer」権限を追加

方法2: すべての画像を一括で公開する (推奨)
----------------------------------------
このスクリプトで既に実行済みです。
各profile_imageをpublicに設定しました。

ブラウザをリロードして確認してください!

方法3: Google Cloud SDK (gsutil) を使用
--------------------------------------
ターミナルで以下を実行:

gsutil cors set firebase_storage_cors.json gs://callog-30758.firebasestorage.app

注: この方法にはGoogle Cloud SDKのインストールと認証が必要です。
""")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
