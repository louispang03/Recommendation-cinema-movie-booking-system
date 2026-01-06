#!/usr/bin/env python3
"""
Export Firebase movies to CSV format for Dify Knowledge Base
"""

import firebase_admin
from firebase_admin import credentials, firestore
import csv
import json

# Initialize Firebase (you'll need to add your service account key)
# cred = credentials.Certificate('path/to/your/service-account-key.json')
# firebase_admin.initialize_app(cred)

# For now, we'll create a sample export script
def export_movies_to_csv():
    """Export movies from Firebase to CSV for Dify"""
    
    # Sample movie data structure (replace with actual Firebase data)
    movies = [
        {
            "title": "Nobody 2",
            "year": "2025",
            "genres": ["Action", "Thriller"],
            "rating": 7.2,
            "overview": "Former assassin Hutch Mansell takes his family on a nostalgic vacation to a small-town theme park, only to find himself in a deadly game of cat and mouse with a ruthless crime syndicate.",
            "director": "Ilya Naishuller",
            "cast": ["Bob Odenkirk", "Connie Nielsen", "Christopher Lloyd"]
        },
        {
            "title": "The Naked Gun",
            "year": "2025", 
            "genres": ["Action", "Comedy", "Crime"],
            "rating": 6.8,
            "overview": "Only one man has the particular set of skills... to lead Police Squad and save the world: Lt. Frank Drebin.",
            "director": "Akiva Schaffer",
            "cast": ["Liam Neeson", "Pamela Anderson", "Kevin Durand"]
        },
        {
            "title": "The Conjuring: Last Rites",
            "year": "2025",
            "genres": ["Horror"],
            "rating": 6.9,
            "overview": "Paranormal investigators Ed and Lorraine Warren take on one last terrifying case involving mysterious disappearances and supernatural entities.",
            "director": "Michael Chaves",
            "cast": ["Patrick Wilson", "Vera Farmiga", "Sterling Jerins"]
        }
    ]
    
    # Export to CSV
    with open('movies_for_dify.csv', 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['title', 'year', 'genres', 'rating', 'overview', 'director', 'cast']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for movie in movies:
            # Convert lists to strings for CSV
            movie_copy = movie.copy()
            movie_copy['genres'] = ', '.join(movie['genres'])
            movie_copy['cast'] = ', '.join(movie['cast'])
            writer.writerow(movie_copy)
    
    print("✅ Movies exported to movies_for_dify.csv")
    
    # Also export to JSON for reference
    with open('movies_for_dify.json', 'w', encoding='utf-8') as jsonfile:
        json.dump(movies, jsonfile, indent=2, ensure_ascii=False)
    
    print("✅ Movies also exported to movies_for_dify.json")

if __name__ == "__main__":
    export_movies_to_csv()
