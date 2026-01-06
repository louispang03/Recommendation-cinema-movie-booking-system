#!/usr/bin/env python3
"""
Firebase Setup Script for Recommendation Engine
This script helps you set up Firebase authentication for the recommendation engine.
"""

import os
import json
import subprocess
import sys

def check_firebase_tools():
    """Check if Firebase CLI is installed"""
    try:
        result = subprocess.run(['firebase', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ Firebase CLI found: {result.stdout.strip()}")
            return True
        else:
            print("❌ Firebase CLI not found")
            return False
    except FileNotFoundError:
        print("❌ Firebase CLI not found")
        return False

def check_gcloud_tools():
    """Check if Google Cloud CLI is installed"""
    try:
        result = subprocess.run(['gcloud', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ Google Cloud CLI found: {result.stdout.strip().split()[0]}")
            return True
        else:
            print("❌ Google Cloud CLI not found")
            return False
    except FileNotFoundError:
        print("❌ Google Cloud CLI not found")
        return False

def create_service_account_key():
    """Create a service account key using gcloud"""
    print("\n🔑 Creating Firebase service account key...")
    
    try:
        # Get the project ID
        project_id = "fyp-cinema"
        print(f"Using project ID: {project_id}")
        
        # Create service account
        service_account_name = "recommendation-engine"
        service_account_email = f"{service_account_name}@{project_id}.iam.gserviceaccount.com"
        
        print(f"Creating service account: {service_account_email}")
        
        # Create the service account
        create_cmd = [
            'gcloud', 'iam', 'service-accounts', 'create', service_account_name,
            '--display-name', 'Recommendation Engine Service Account',
            '--description', 'Service account for the movie recommendation engine',
            '--project', project_id
        ]
        
        result = subprocess.run(create_cmd, capture_output=True, text=True)
        if result.returncode != 0 and "already exists" not in result.stderr:
            print(f"❌ Error creating service account: {result.stderr}")
            return False
        
        print("✅ Service account created or already exists")
        
        # Grant necessary permissions
        roles = [
            'roles/datastore.user',  # Firestore access
            'roles/storage.objectViewer'  # Storage access
        ]
        
        for role in roles:
            grant_cmd = [
                'gcloud', 'projects', 'add-iam-policy-binding', project_id,
                '--member', f'serviceAccount:{service_account_email}',
                '--role', role
            ]
            
            result = subprocess.run(grant_cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✅ Granted role: {role}")
            else:
                print(f"⚠️  Warning: Could not grant role {role}: {result.stderr}")
        
        # Create and download the key
        key_file = "serviceAccountKey.json"
        create_key_cmd = [
            'gcloud', 'iam', 'service-accounts', 'keys', 'create', key_file,
            '--iam-account', service_account_email,
            '--project', project_id
        ]
        
        result = subprocess.run(create_key_cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ Service account key created: {key_file}")
            return True
        else:
            print(f"❌ Error creating service account key: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_firebase_connection():
    """Test the Firebase connection"""
    print("\n🧪 Testing Firebase connection...")
    
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        
        # Initialize Firebase
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        
        # Test connection by reading a document
        movies_ref = db.collection('movies')
        movies = list(movies_ref.limit(1).stream())
        
        if movies:
            print(f"✅ Firebase connection successful! Found {len(movies)} movie(s) in database")
            return True
        else:
            print("⚠️  Firebase connected but no movies found in database")
            return True
            
    except Exception as e:
        print(f"❌ Firebase connection failed: {e}")
        return False

def main():
    """Main setup function"""
    print("🎬 Firebase Setup for Movie Recommendation Engine")
    print("=" * 50)
    
    # Check if service account key already exists
    if os.path.exists("serviceAccountKey.json"):
        print("✅ Service account key file already exists")
        if test_firebase_connection():
            print("\n🎉 Setup complete! You can now run the recommendation engine.")
            return
        else:
            print("❌ Existing key file is not working, will create a new one")
    
    # Check prerequisites
    print("\n📋 Checking prerequisites...")
    
    if not check_gcloud_tools():
        print("\n❌ Google Cloud CLI is required but not installed.")
        print("Please install it from: https://cloud.google.com/sdk/docs/install")
        print("Then run: gcloud auth login")
        return
    
    if not check_firebase_tools():
        print("\n⚠️  Firebase CLI not found, but not required for this setup")
    
    # Create service account key
    if create_service_account_key():
        if test_firebase_connection():
            print("\n🎉 Setup complete! You can now run the recommendation engine.")
            print("\nTo run the recommendation engine:")
            print("  python recommendation_engine.py")
        else:
            print("\n❌ Setup completed but Firebase connection failed")
    else:
        print("\n❌ Setup failed")

if __name__ == "__main__":
    main()
