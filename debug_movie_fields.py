#!/usr/bin/env python3
"""
Debug script to check movie fields in Firebase
"""

import requests
import json

FIREBASE_PROJECT_ID = "fyp-cinema"
FIREBASE_REST_API_BASE = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents"

def debug_movie_fields():
    """Debug movie fields in Firebase"""
    print("🔍 Debugging Movie Fields in Firebase")
    print("=" * 50)
    
    try:
        # Fetch movies collection
        url = f"{FIREBASE_REST_API_BASE}/movies"
        print(f"📡 Fetching: {url}")
        
        response = requests.get(url)
        print(f"📊 Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            documents = data.get('documents', [])
            print(f"📚 Found {len(documents)} movies")
            
            if documents:
                # Show first movie in detail
                first_movie = documents[0]
                fields = first_movie.get('fields', {})
                
                print(f"\n🎬 First Movie: {first_movie.get('name', 'Unknown')}")
                print(f"📋 All fields: {list(fields.keys())}")
                
                # Show each field and its value
                for field_name, field_data in fields.items():
                    if 'stringValue' in field_data:
                        value = field_data['stringValue']
                        print(f"  {field_name}: {value}")
                    elif 'integerValue' in field_data:
                        value = field_data['integerValue']
                        print(f"  {field_name}: {value}")
                    elif 'doubleValue' in field_data:
                        value = field_data['doubleValue']
                        print(f"  {field_name}: {value}")
                    elif 'booleanValue' in field_data:
                        value = field_data['booleanValue']
                        print(f"  {field_name}: {value}")
                    elif 'arrayValue' in field_data:
                        array_data = field_data['arrayValue'].get('values', [])
                        if array_data and 'stringValue' in array_data[0]:
                            values = [item.get('stringValue', '') for item in array_data]
                            print(f"  {field_name}: {values}")
                        else:
                            print(f"  {field_name}: [array with {len(array_data)} items]")
                    else:
                        print(f"  {field_name}: {field_data}")
                
                # Check for image-related fields specifically
                print(f"\n🖼️ Image-related fields:")
                image_fields = ['posterPath', 'imageUrl', 'poster_path', 'backdropPath', 'backdrop_path']
                for field in image_fields:
                    if field in fields:
                        field_data = fields[field]
                        if 'stringValue' in field_data:
                            value = field_data['stringValue']
                            print(f"  ✅ {field}: {value}")
                        else:
                            print(f"  ❌ {field}: {field_data}")
                    else:
                        print(f"  ❌ {field}: Not found")
            
            return True
        else:
            print(f"❌ Failed with status {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    debug_movie_fields()
