from flask import Flask, request, jsonify
import pandas as pd
import requests
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
from datetime import datetime, timedelta
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv('movie_api.env')

# Firebase configuration - using REST API instead of Admin SDK
FIREBASE_PROJECT_ID = "fyp-cinema"
FIREBASE_REST_API_BASE = f"https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}/databases/(default)/documents"

# Try to initialize Firebase REST API
try:
    # Test Firebase connection with a simple request
    test_url = f"{FIREBASE_REST_API_BASE}/movies"
    test_response = requests.get(test_url)
    
    if test_response.status_code == 200:
        FIREBASE_ENABLED = True
        print("[SUCCESS] Firebase REST API connected successfully")
    else:
        print(f"[ERROR] Firebase REST API test failed: {test_response.status_code}")
        FIREBASE_ENABLED = False
except Exception as e:
    print(f"[ERROR] Firebase REST API initialization failed: {e}")
    FIREBASE_ENABLED = False

API_KEY = os.getenv('TMDB_API_KEY')
if not API_KEY:
    print("[WARNING] TMDB_API_KEY not found in environment variables or movie_api.env")
TMDB_BASE = 'https://api.themoviedb.org/3'

app = Flask(__name__)

class MovieRecommendationEngine:
    def __init__(self):
        self.movie_cache = {}
        self.genre_mapping = {
            28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
            80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
            14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
            9648: "Mystery", 10749: "Romance", 878: "Science Fiction",
            10770: "TV Movie", 53: "Thriller", 10752: "War", 37: "Western"
        }
        
        # Genre similarity mapping for fuzzy matching
        self.genre_similarity = {
            "Action": ["Adventure", "Thriller", "Crime", "War"],
            "Adventure": ["Action", "Fantasy", "Thriller"],
            "Animation": ["Family", "Comedy", "Fantasy"],
            "Comedy": ["Animation", "Family", "Romance"],
            "Crime": ["Action", "Thriller", "Mystery", "Drama"],
            "Documentary": ["History", "Drama"],
            "Drama": ["Romance", "Crime", "History", "War"],
            "Family": ["Animation", "Comedy", "Adventure"],
            "Fantasy": ["Adventure", "Animation", "Sci-Fi"],
            "History": ["Drama", "War", "Documentary"],
            "Horror": ["Thriller", "Mystery"],
            "Music": ["Drama", "Comedy"],
            "Mystery": ["Thriller", "Crime", "Horror"],
            "Romance": ["Drama", "Comedy"],
            "Science Fiction": ["Fantasy", "Action", "Adventure", "Thriller"],
            "Sci-Fi": ["Fantasy", "Action", "Adventure", "Thriller"],  # Alternative name
            "Thriller": ["Action", "Crime", "Mystery", "Horror"],
            "War": ["Action", "Drama", "History"],
            "Western": ["Action", "Adventure", "Drama"]
        }
    
    def calculate_genre_match_score(self, user_genres, movie_genres):
        """
        Calculate genre match score with fuzzy matching
        Returns (score, matched_genres, explanation)
        """
        if not user_genres or not movie_genres:
            return 0.0, [], "No genres to match"
        
        total_score = 0.0
        matched_genres = []
        explanations = []
        
        for user_genre in user_genres:
            best_match_score = 0.0
            best_match_genre = None
            match_type = ""
            
            # Check for exact matches first
            for movie_genre in movie_genres:
                if user_genre.lower() == movie_genre.lower():
                    best_match_score = 1.0  # Perfect match
                    best_match_genre = movie_genre
                    match_type = "exact"
                    break
                # Handle common variations
                elif (user_genre == "Sci-Fi" and movie_genre == "Science Fiction") or \
                     (user_genre == "Science Fiction" and movie_genre == "Sci-Fi"):
                    best_match_score = 1.0  # Perfect match
                    best_match_genre = movie_genre
                    match_type = "exact"
                    break
            
            # If no exact match, check for similar genres
            if best_match_score == 0.0 and user_genre in self.genre_similarity:
                similar_genres = self.genre_similarity[user_genre]
                for movie_genre in movie_genres:
                    if movie_genre in similar_genres:
                        # Similar genre gets 0.7 score
                        if 0.7 > best_match_score:
                            best_match_score = 0.7
                            best_match_genre = movie_genre
                            match_type = "similar"
            
            if best_match_score > 0:
                total_score += best_match_score
                matched_genres.append(best_match_genre)
                explanations.append(f"{user_genre} -> {best_match_genre} ({match_type})")
        
        # Normalize score (average of all user genres)
        final_score = total_score / len(user_genres)
        explanation = "; ".join(explanations) if explanations else "No genre matches found"
        
        return final_score, matched_genres, explanation
    
    def fetch_movie_metadata(self, movie_id):
        """Fetch movie metadata from database using REST API"""
        if movie_id in self.movie_cache:
            return self.movie_cache[movie_id]
        
        try:
            if FIREBASE_ENABLED:
                print(f"[INFO] Fetching movie metadata from database for ID: {movie_id}")
                url = f"{FIREBASE_REST_API_BASE}/movies/{movie_id}"
                response = requests.get(url)
                
                if response.status_code == 200:
                    data = response.json()
                    # Convert Firestore REST API format to our format
                    fields = data.get('fields', {})
                    
                    # Helper function to extract values from Firestore format
                    def get_field_value(field_data, default=None):
                        if not field_data:
                            return default
                        if 'stringValue' in field_data:
                            return field_data['stringValue']
                        elif 'integerValue' in field_data:
                            return int(field_data['integerValue'])
                        elif 'doubleValue' in field_data:
                            return float(field_data['doubleValue'])
                        elif 'booleanValue' in field_data:
                            return field_data['booleanValue']
                        elif 'arrayValue' in field_data:
                            return [get_field_value(item) for item in field_data['arrayValue'].get('values', [])]
                        elif 'mapValue' in field_data:
                            return {k: get_field_value(v) for k, v in field_data['mapValue'].get('fields', {}).items()}
                        return default
                    
                    # Extract movie data
                    movie_data = {
                        'id': get_field_value(fields.get('id'), movie_id),
                        'title': get_field_value(fields.get('title'), 'Unknown'),
                        'overview': get_field_value(fields.get('overview'), ''),
                        'poster_path': get_field_value(fields.get('poster_path')) or get_field_value(fields.get('backdrop_path')),
                        'imageUrl': get_field_value(fields.get('imageUrl')),
                        'backdrop_path': get_field_value(fields.get('backdropPath')),
                        'genres': get_field_value(fields.get('genres'), []),
                        'genre_ids': get_field_value(fields.get('genreIds'), []),
                        'keywords': [],  # Not stored in database
                        'cast': [actor.get('name', '') for actor in get_field_value(fields.get('cast'), [])[:5]] if get_field_value(fields.get('cast')) else [],
                        'director': '',  # Not stored in database
                        'release_date': get_field_value(fields.get('releaseDate'), ''),
                        'vote_average': get_field_value(fields.get('voteAverage'), 0),
                        'popularity': 0,  # Not stored in database
                        'runtime': get_field_value(fields.get('runtime'), 0),
                        'original_language': get_field_value(fields.get('originalLanguage'), ''),
                        'isFromTMDB': get_field_value(fields.get('isFromTMDB'), False),
                        'categories': get_field_value(fields.get('categories'), []),
                        'cinemaBrands': get_field_value(fields.get('cinemaBrands'), [])
                    }
                    
                    print(f"[SUCCESS] Successfully fetched movie from database: {movie_data['title']}")
                    self.movie_cache[movie_id] = movie_data
                    return movie_data
                else:
                    print(f"[ERROR] Movie not found in database: {movie_id} (Status: {response.status_code})")
                    return None
            else:
                print("[ERROR] Firebase not available, cannot fetch from database")
                return None
        except Exception as e:
            print(f"Error fetching movie {movie_id} from database: {e}")
            return None
    
    def fetch_popular_movies(self, page=1):
        """Fetch movies from database using REST API"""
        try:
            if FIREBASE_ENABLED:
                print(f"[INFO] Fetching movies from database (page {page})")
                url = f"{FIREBASE_REST_API_BASE}/movies"
                response = requests.get(url)
                
                if response.status_code == 200:
                    data = response.json()
                    movies = []
                    
                    # Helper function to extract values from Firestore format
                    def get_field_value(field_data, default=None):
                        if not field_data:
                            return default
                        if 'stringValue' in field_data:
                            return field_data['stringValue']
                        elif 'integerValue' in field_data:
                            return int(field_data['integerValue'])
                        elif 'doubleValue' in field_data:
                            return float(field_data['doubleValue'])
                        elif 'booleanValue' in field_data:
                            return field_data['booleanValue']
                        elif 'arrayValue' in field_data:
                            return [get_field_value(item) for item in field_data['arrayValue'].get('values', [])]
                        elif 'mapValue' in field_data:
                            return {k: get_field_value(v) for k, v in field_data['mapValue'].get('fields', {}).items()}
                        return default
                    
                    # Process each movie document
                    for doc in data.get('documents', []):
                        fields = doc.get('fields', {})
                        movie = {
                            'id': get_field_value(fields.get('id')),
                            'title': get_field_value(fields.get('title'), 'Unknown'),
                            'overview': get_field_value(fields.get('overview'), ''),
                            'poster_path': get_field_value(fields.get('poster_path')) or get_field_value(fields.get('backdrop_path')),
                            'imageUrl': get_field_value(fields.get('imageUrl')),
                            'backdrop_path': get_field_value(fields.get('backdropPath')),
                            'genres': get_field_value(fields.get('genres'), []),
                            'genre_ids': get_field_value(fields.get('genreIds'), []),
                            'release_date': get_field_value(fields.get('releaseDate'), ''),
                            'vote_average': get_field_value(fields.get('voteAverage'), 0),
                            'popularity': 0,  # Not stored in database
                            'runtime': get_field_value(fields.get('runtime'), 0),
                            'original_language': get_field_value(fields.get('originalLanguage'), ''),
                            'isFromTMDB': get_field_value(fields.get('isFromTMDB'), False),
                            'categories': get_field_value(fields.get('categories'), []),
                            'cinemaBrands': get_field_value(fields.get('cinemaBrands'), [])
                        }
                        movies.append(movie)
                    
                    print(f"[SUCCESS] Fetched {len(movies)} movies from database")
                    return movies
                else:
                    print(f"[ERROR] Failed to fetch movies from database: {response.status_code}")
                    return self._get_mock_movies()
            else:
                print("[ERROR] Firebase not available, using mock data for recommendations")
                return self._get_mock_movies()
        except Exception as e:
            print(f"Error fetching movies from database: {e}")
            print("Using mock data for recommendations")
            return self._get_mock_movies()
    
    def _get_mock_movies(self):
        """Get mock movies for testing when Firebase is not available"""
        return [
            {
                'id': '1',
                'title': 'The Dark Knight',
                'overview': 'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.',
                'poster_path': '/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
                'backdrop_path': '/hqkIcbrOHL86UncnHIsHVcVmzue.jpg',
                'genres': ['Action', 'Crime', 'Drama'],
                'genre_ids': [28, 80, 18],
                'release_date': '2008-07-18',
                'vote_average': 9.0,
                'popularity': 85.0,
                'runtime': 152,
                'original_language': 'en',
                'isFromTMDB': True,
                'categories': ['now_playing', 'popular'],
                'cinemaBrands': ['GSC', 'LFS', 'mmCineplexes']
            },
            {
                'id': '2',
                'title': 'Inception',
                'overview': 'A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.',
                'poster_path': '/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
                'backdrop_path': '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
                'genres': ['Action', 'Sci-Fi', 'Thriller'],
                'genre_ids': [28, 878, 53],
                'release_date': '2010-07-16',
                'vote_average': 8.8,
                'popularity': 78.0,
                'runtime': 148,
                'original_language': 'en',
                'isFromTMDB': True,
                'categories': ['now_playing', 'popular'],
                'cinemaBrands': ['GSC', 'LFS']
            },
            {
                'id': '3',
                'title': 'Interstellar',
                'overview': 'The adventures of a group of explorers who make use of a newly discovered wormhole to surpass the limitations on human space travel and conquer the vast distances involved in an interstellar voyage.',
                'poster_path': '/rAiYTfKGqDCRIIqo664sY9XZIvQ.jpg',
                'backdrop_path': '/5a4wdoq7CBrEZMpBrKQjv7E2R5M.jpg',
                'genres': ['Adventure', 'Drama', 'Sci-Fi'],
                'genre_ids': [12, 18, 878],
                'release_date': '2014-11-07',
                'vote_average': 8.6,
                'popularity': 72.0,
                'runtime': 169,
                'original_language': 'en',
                'isFromTMDB': True,
                'categories': ['now_playing'],
                'cinemaBrands': ['GSC', 'mmCineplexes']
            },
            {
                'id': '4',
                'title': 'The Matrix',
                'overview': 'A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.',
                'poster_path': '/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
                'backdrop_path': '/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg',
                'genres': ['Action', 'Sci-Fi'],
                'genre_ids': [28, 878],
                'release_date': '1999-03-31',
                'vote_average': 8.7,
                'popularity': 65.0,
                'runtime': 136,
                'original_language': 'en',
                'isFromTMDB': True,
                'categories': ['popular'],
                'cinemaBrands': ['LFS', 'mmCineplexes']
            },
            {
                'id': '5',
                'title': 'Pulp Fiction',
                'overview': 'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.',
                'poster_path': '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg',
                'backdrop_path': '/4cDFJr4H91XNjI48hpbLDNeA2tk.jpg',
                'genres': ['Crime', 'Drama'],
                'genre_ids': [80, 18],
                'release_date': '1994-10-14',
                'vote_average': 8.9,
                'popularity': 58.0,
                'runtime': 154,
                'original_language': 'en',
                'isFromTMDB': True,
                'categories': ['popular'],
                'cinemaBrands': ['GSC', 'LFS']
            }
        ]
    
    def get_user_booking_history(self, user_id, booking_history=None):
        """Get user's booking history - now receives data from Flutter"""
        try:
            # Use booking history provided by Flutter (preferred method)
            if booking_history is not None:
                print(f"Using booking history from Flutter: {len(booking_history)} bookings")
                processed_bookings = []
                
                for booking in booking_history:
                    # Process the booking data from Flutter
                    processed_booking = {
                        'movieId': str(booking.get('movieId', '')),
                        'movieTitle': booking.get('movieTitle', ''),
                        'date': booking.get('date', ''),
                        'time': booking.get('time', ''),
                        'seats': booking.get('seats', []),
                        'cinema': booking.get('cinema', 'GSC'),
                        'totalPrice': booking.get('totalPrice', 0),
                        'status': booking.get('status', 'active'),
                        'bookingDate': booking.get('bookingDate', '')
                    }
                    
                    # Handle bookingDate conversion
                    try:
                        if isinstance(processed_booking['bookingDate'], str):
                            from datetime import datetime
                            booking_dt = datetime.fromisoformat(processed_booking['bookingDate'].replace('Z', '+00:00'))
                            processed_booking['bookingDate'] = booking_dt.strftime('%Y-%m-%d')
                    except Exception as e:
                        print(f"Date conversion error: {e}")
                        processed_booking['bookingDate'] = processed_booking.get('date', '2024-01-01')
                    
                    processed_bookings.append(processed_booking)
                    print(f"Processed booking: {processed_booking['movieTitle']} on {processed_booking['date']}")
                
                return processed_bookings
            
            # Fallback: Try Firebase if available (original method)
            if FIREBASE_ENABLED:
                print("Flutter didn't provide booking history, trying Firebase...")
                # Note: This fallback method is not implemented as we're using REST API
                print("Firebase fallback not implemented - using mock data")
            
            # Final fallback: Mock data
            print("No booking history available, using mock data")
            return [
                {'movieId': '550', 'movieTitle': 'Fight Club', 'bookingDate': '2024-01-15'},
                {'movieId': '13', 'movieTitle': 'Forrest Gump', 'bookingDate': '2024-01-10'},
            ]
            
        except Exception as e:
            print(f"Error processing booking history: {e}")
            return []
    
    def create_user_profile(self, user_id, booking_history):
        """Create user profile based on booking history"""
        if not booking_history:
            return None
        
        user_movies = []
        for booking in booking_history:
            movie_data = self.fetch_movie_metadata(booking['movieId'])
            if movie_data:
                user_movies.append(movie_data)
        
        # If no movies found from database, try to create profile from mock data
        if not user_movies and not FIREBASE_ENABLED:
            print("Creating user profile from mock data based on booking history")
            mock_movies = self._get_mock_movies()
            for booking in booking_history:
                # Find matching movie in mock data
                for movie in mock_movies:
                    if str(movie['id']) == str(booking['movieId']):
                        user_movies.append(movie)
                        break
        
        if not user_movies:
            print("No movies found for user profile creation")
            return None
        
        # Aggregate user preferences
        user_profile = {
            'preferred_genres': {},
            'preferred_actors': {},
            'preferred_directors': {},
            'avg_rating_preference': 0,
            'avg_runtime_preference': 0,
            'total_bookings': len(user_movies)
        }
        
        # Calculate preferences
        for movie in user_movies:
            # Genre preferences
            for genre in movie.get('genres', []):
                user_profile['preferred_genres'][genre] = user_profile['preferred_genres'].get(genre, 0) + 1
            
            # Actor preferences
            for actor in movie.get('cast', []):
                user_profile['preferred_actors'][actor] = user_profile['preferred_actors'].get(actor, 0) + 1
            
            # Director preferences
            if movie.get('director'):
                user_profile['preferred_directors'][movie['director']] = user_profile['preferred_directors'].get(movie['director'], 0) + 1
            
            # Rating and runtime preferences
            user_profile['avg_rating_preference'] += movie.get('vote_average', 0)
            user_profile['avg_runtime_preference'] += movie.get('runtime', 0)
        
        # Calculate averages
        if len(user_movies) > 0:
            user_profile['avg_rating_preference'] /= len(user_movies)
            user_profile['avg_runtime_preference'] /= len(user_movies)
        
        print(f"Created user profile with {len(user_movies)} movies")
        return user_profile
    
    def get_watched_movie_ids(self, booking_history):
        """Extract unique movie IDs from user's booking history"""
        watched_ids = set()
        for booking in booking_history:
            movie_id = str(booking.get('movieId', ''))
            if movie_id and movie_id != '':
                watched_ids.add(movie_id)
        print(f"[INFO] Found {len(watched_ids)} watched movies: {list(watched_ids)}")
        return watched_ids
    
    def calculate_movie_similarity(self, target_movie, candidate_movies, user_profile=None):
        """Calculate similarity between movies with optional user profile weighting"""
        similarities = []
        
        # Create content vectors
        all_movies = [target_movie] + candidate_movies
        movie_texts = []
        
        for movie in all_movies:
            text_features = [
                movie['overview'],
                ' '.join(movie['genres']),
                ' '.join(movie['keywords']),
                ' '.join(movie['cast']),
                movie['director']
            ]
            movie_texts.append(' '.join(text_features))
        
        # Calculate TF-IDF similarity
        tfidf = TfidfVectorizer(stop_words='english', max_features=5000)
        tfidf_matrix = tfidf.fit_transform(movie_texts)
        content_similarities = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:]).flatten()
        
        # If user profile exists, add preference-based scoring
        for i, movie in enumerate(candidate_movies):
            content_score = content_similarities[i]
            preference_score = 0
            
            if user_profile:
                # Genre preference scoring
                genre_score = sum(user_profile['preferred_genres'].get(genre, 0) for genre in movie['genres'])
                genre_score = min(genre_score / user_profile['total_bookings'], 1.0)
                
                # Actor preference scoring
                actor_score = sum(user_profile['preferred_actors'].get(actor, 0) for actor in movie['cast'])
                actor_score = min(actor_score / user_profile['total_bookings'], 1.0)
                
                # Director preference scoring
                director_score = user_profile['preferred_directors'].get(movie['director'], 0) / user_profile['total_bookings']
                
                # Rating preference (prefer movies close to user's average rating preference)
                rating_diff = abs(movie['vote_average'] - user_profile['avg_rating_preference'])
                rating_score = max(0, 1 - rating_diff / 10)  # Normalize to 0-1
                
                # Combine preference scores
                preference_score = (genre_score * 0.4 + actor_score * 0.3 + director_score * 0.2 + rating_score * 0.1)
            
            # Combine content and preference scores
            final_score = content_score * 0.6 + preference_score * 0.4 if user_profile else content_score
            similarities.append(final_score)
        
        return similarities
    
    def normalize_similarity_score(self, score):
        """Convert similarity score to percentage (0-100%)"""
        # Ensure score is between 0 and 1, then convert to percentage
        normalized_score = max(0, min(1, score))
        return round(normalized_score * 100, 1)
    
    def get_confidence_explanation(self, score, user_profile=None):
        """Generate human-readable explanation for similarity score"""
        percentage = self.normalize_similarity_score(score)
        
        if percentage >= 90:
            return f"{percentage}% match - Excellent fit based on your preferences"
        elif percentage >= 80:
            return f"{percentage}% match - Very good match for your taste"
        elif percentage >= 70:
            return f"{percentage}% match - Good recommendation based on your history"
        elif percentage >= 60:
            return f"{percentage}% match - Decent match with your interests"
        elif percentage >= 50:
            return f"{percentage}% match - Somewhat relevant to your preferences"
        else:
            return f"{percentage}% match - Based on general popularity"
    
    def hybrid_sort_recommendations(self, recommendations, user_profile=None):
        """Sort recommendations by similarity first, then popularity as tiebreaker"""
        def sort_key(movie):
            # Primary: similarity score (higher is better)
            similarity_score = movie.get('similarity_score', 0) or movie.get('preference_score', 0)
            
            # Secondary: popularity score (higher is better)
            popularity_score = movie.get('popularity', 0)
            
            # Tertiary: vote average (higher is better)
            vote_average = movie.get('vote_average', 0)
            
            # Return tuple for sorting: (similarity, popularity, vote_average)
            # Use negative values for descending order
            return (-similarity_score, -popularity_score, -vote_average)
        
        return sorted(recommendations, key=sort_key)
    def get_most_booked_movies(self, limit=10):
        """Get the most booked movies from user booking history"""
        try:
            print(f"[INFO] Fetching most booked movies from user booking data")
            
            if not FIREBASE_ENABLED:
                print("[INFO] Firebase not enabled, cannot fetch booking data")
                return []
            
            # Fetch all user bookings from Firestore
            url = f"{FIREBASE_REST_API_BASE}/bookings"
            response = requests.get(url)
            
            if response.status_code != 200:
                print(f"[ERROR] Failed to fetch bookings from Firestore: {response.status_code}")
                return []
            
            data = response.json()
            documents = data.get('documents', [])
            print(f"[INFO] Fetched {len(documents)} booking records")
            
            # Helper function to extract values from Firestore format
            def get_field_value(field_data, default=None):
                if not field_data:
                    return default
                if 'stringValue' in field_data:
                    return field_data['stringValue']
                elif 'integerValue' in field_data:
                    return int(field_data['integerValue'])
                elif 'doubleValue' in field_data:
                    return float(field_data['doubleValue'])
                elif 'booleanValue' in field_data:
                    return field_data['booleanValue']
                elif 'arrayValue' in field_data:
                    return [get_field_value(item) for item in field_data['arrayValue'].get('values', [])]
                elif 'mapValue' in field_data:
                    return {k: get_field_value(v) for k, v in field_data['mapValue'].get('fields', {}).items()}
                return default
            
            # Count movie bookings
            movie_booking_counts = {}
            for doc in documents:
                fields = doc.get('fields', {})
                movie_id = get_field_value(fields.get('movieId'))
                movie_title = get_field_value(fields.get('movieTitle'))
                
                if movie_id and movie_title:
                    if movie_id not in movie_booking_counts:
                        movie_booking_counts[movie_id] = {
                            'count': 0,
                            'title': movie_title,
                            'movie_id': movie_id
                        }
                    movie_booking_counts[movie_id]['count'] += 1
            
            # Sort by booking count
            sorted_movies = sorted(movie_booking_counts.values(), key=lambda x: x['count'], reverse=True)
            print(f"[INFO] Found {len(sorted_movies)} unique movies in booking history")
            
            # Get detailed movie data for top booked movies
            most_booked_movies = []
            for movie_data in sorted_movies[:limit]:
                movie_details = self.fetch_movie_by_id(movie_data['movie_id'])
                if movie_details:
                    movie_details['booking_count'] = movie_data['count']
                    movie_details['confidence_percentage'] = 75  # High confidence for popular movies
                    movie_details['recommendation_reason'] = f"75% match - Popular choice (booked {movie_data['count']} times by other users)"
                    movie_details['genre_match_explanation'] = f"Most booked movie among users"
                    most_booked_movies.append(movie_details)
            
            print(f"[SUCCESS] Retrieved {len(most_booked_movies)} most booked movies")
            return most_booked_movies
            
        except Exception as e:
            print(f"[ERROR] Error fetching most booked movies: {str(e)}")
            return []

    def fetch_movie_by_id(self, movie_id):
        """Fetch detailed movie data by ID"""
        try:
            if not FIREBASE_ENABLED:
                return None
                
            url = f"{FIREBASE_REST_API_BASE}/movies/{movie_id}"
            response = requests.get(url)
            
            if response.status_code != 200:
                print(f"[ERROR] Movie {movie_id} not found in database")
                return None
            
            doc = response.json()
            fields = doc.get('fields', {})
            
            # Helper function to extract values from Firestore format
            def get_field_value(field_data, default=None):
                if not field_data:
                    return default
                if 'stringValue' in field_data:
                    return field_data['stringValue']
                elif 'integerValue' in field_data:
                    return int(field_data['integerValue'])
                elif 'doubleValue' in field_data:
                    return float(field_data['doubleValue'])
                elif 'booleanValue' in field_data:
                    return field_data['booleanValue']
                elif 'arrayValue' in field_data:
                    return [get_field_value(item) for item in field_data['arrayValue'].get('values', [])]
                elif 'mapValue' in field_data:
                    return {k: get_field_value(v) for k, v in field_data['mapValue'].get('fields', {}).items()}
                return default
            
            return {
                'id': get_field_value(fields.get('id')),
                'title': get_field_value(fields.get('title'), 'Unknown'),
                'overview': get_field_value(fields.get('overview'), ''),
                'poster_path': get_field_value(fields.get('poster_path')) or get_field_value(fields.get('backdrop_path')),
                'imageUrl': get_field_value(fields.get('imageUrl')),
                'backdrop_path': get_field_value(fields.get('backdropPath')),
                'genres': get_field_value(fields.get('genres'), []),
                'genre_ids': get_field_value(fields.get('genreIds'), []),
                'release_date': get_field_value(fields.get('releaseDate'), ''),
                'vote_average': get_field_value(fields.get('voteAverage'), 0),
                'popularity': 0,
                'runtime': get_field_value(fields.get('runtime'), 0),
                'original_language': get_field_value(fields.get('originalLanguage'), ''),
                'isFromTMDB': get_field_value(fields.get('isFromTMDB'), False),
                'categories': get_field_value(fields.get('categories'), []),
                'cinemaBrands': get_field_value(fields.get('cinemaBrands'), []),
                'cast': [actor.get('name', '') for actor in get_field_value(fields.get('cast'), [])[:5]] if get_field_value(fields.get('cast')) else []
            }
            
        except Exception as e:
            print(f"[ERROR] Error fetching movie by ID {movie_id}: {str(e)}")
            return None
    
    def get_genre_based_recommendations(self, preferred_genres, preferred_actors=None):
        """Get recommendations based on genre and actor preferences for new users"""
        recommendations = []
        
        try:
            if FIREBASE_ENABLED:
                print(f"[INFO] Fetching genre-based recommendations from database for genres: {preferred_genres}")
                url = f"{FIREBASE_REST_API_BASE}/movies"
                response = requests.get(url)
                
                if response.status_code == 200:
                    data = response.json()
                    
                    # Helper function to extract values from Firestore format
                    def get_field_value(field_data, default=None):
                        if not field_data:
                            return default
                        if 'stringValue' in field_data:
                            return field_data['stringValue']
                        elif 'integerValue' in field_data:
                            return int(field_data['integerValue'])
                        elif 'doubleValue' in field_data:
                            return float(field_data['doubleValue'])
                        elif 'booleanValue' in field_data:
                            return field_data['booleanValue']
                        elif 'arrayValue' in field_data:
                            return [get_field_value(item) for item in field_data['arrayValue'].get('values', [])]
                        elif 'mapValue' in field_data:
                            return {k: get_field_value(v) for k, v in field_data['mapValue'].get('fields', {}).items()}
                        return default
                    
                    # Process each movie document
                    for doc in data.get('documents', []):
                        fields = doc.get('fields', {})
                        movie_genres = get_field_value(fields.get('genres'), [])
                        
                        # Use fuzzy genre matching
                        genre_score, matched_genres, genre_explanation = self.calculate_genre_match_score(preferred_genres, movie_genres)
                        
                        # Only include movies with some genre match (score > 0)
                        if genre_score > 0:
                            # Convert to recommendation format
                            movie = {
                                'id': get_field_value(fields.get('id')),
                                'title': get_field_value(fields.get('title'), 'Unknown'),
                                'overview': get_field_value(fields.get('overview'), ''),
                                'poster_path': get_field_value(fields.get('poster_path')) or get_field_value(fields.get('backdrop_path')),
                                'imageUrl': get_field_value(fields.get('imageUrl')),
                                'backdrop_path': get_field_value(fields.get('backdropPath')),
                                'genres': movie_genres,
                                'genre_ids': get_field_value(fields.get('genreIds'), []),
                                'release_date': get_field_value(fields.get('releaseDate'), ''),
                                'vote_average': get_field_value(fields.get('voteAverage'), 0),
                                'popularity': 0,
                                'runtime': get_field_value(fields.get('runtime'), 0),
                                'original_language': get_field_value(fields.get('originalLanguage'), ''),
                                'isFromTMDB': get_field_value(fields.get('isFromTMDB'), False),
                                'categories': get_field_value(fields.get('categories'), []),
                                'cinemaBrands': get_field_value(fields.get('cinemaBrands'), []),
                                'cast': [actor.get('name', '') for actor in get_field_value(fields.get('cast'), [])[:5]] if get_field_value(fields.get('cast')) else []
                            }
                            
                            # Calculate confidence score using fuzzy genre matching
                            base_genre_score = genre_score * 0.8  # Genre match worth up to 80%
                            actor_match_score = 0.2 if preferred_actors and any(actor in movie['cast'] for actor in preferred_actors) else 0.0
                            confidence_score = base_genre_score + actor_match_score
                            
                            movie['confidence_percentage'] = self.normalize_similarity_score(confidence_score)
                            movie['genre_match_explanation'] = genre_explanation
                            
                            # Create detailed recommendation reason
                            if preferred_actors and any(actor in movie['cast'] for actor in preferred_actors):
                                matched_actors = set(movie['cast']) & set(preferred_actors)
                                movie['recommendation_reason'] = f"{movie['confidence_percentage']}% match - {', '.join(matched_genres)} movie featuring {', '.join(matched_actors)}"
                            else:
                                movie['recommendation_reason'] = f"{movie['confidence_percentage']}% match - {', '.join(matched_genres)} movie based on your preferences"
                            
                            # Add debug info
                            movie['debug_info'] = {
                                'genre_score': genre_score,
                                'actor_score': actor_match_score,
                                'matched_genres': matched_genres,
                                'genre_explanation': genre_explanation
                            }
                            
                            recommendations.append(movie)
                    
                    print(f"[SUCCESS] Found {len(recommendations)} genre-based recommendations from database")
                    
                    # Debug: Show confidence scores of found recommendations
                    if recommendations:
                        confidence_scores = [r.get('confidence_percentage', 0) for r in recommendations]
                        print(f"[DEBUG] Confidence scores: {confidence_scores}")
                    
                    # Check if we have good quality recommendations or need fallback
                    high_confidence_recommendations = [r for r in recommendations if r.get('confidence_percentage', 0) >= 60]
                    print(f"[DEBUG] High confidence recommendations: {len(high_confidence_recommendations)}/{len(recommendations)}")
                    
                    # If no recommendations found OR all recommendations have low confidence, use fallback
                    if len(recommendations) == 0 or len(high_confidence_recommendations) == 0:
                        if len(recommendations) == 0:
                            print(f"[INFO] No genre matches found for {preferred_genres}, trying most booked movies as fallback")
                        else:
                            print(f"[INFO] Only low-confidence matches found for {preferred_genres} (best: {max([r.get('confidence_percentage', 0) for r in recommendations])}%), trying most booked movies as fallback")
                        
                        # Try to get most booked movies first
                        most_booked = self.get_most_booked_movies(10)
                        
                        if most_booked:
                            if len(recommendations) == 0:
                                print(f"[SUCCESS] Using {len(most_booked)} most booked movies as recommendations")
                                for movie in most_booked:
                                    movie['recommendation_reason'] = f"75% match - Popular choice among users (booked {movie['booking_count']} times, no exact match for {', '.join(preferred_genres)})"
                                    movie['genre_match_explanation'] = f"No matches found for {preferred_genres}, showing most booked movies by other users"
                                recommendations.extend(most_booked)
                            else:
                                print(f"[SUCCESS] Replacing low-confidence recommendations with {len(most_booked)} most booked movies")
                                # Clear low-confidence recommendations and use most booked instead
                                recommendations.clear()
                                for movie in most_booked:
                                    movie['recommendation_reason'] = f"75% match - Popular choice among users (booked {movie['booking_count']} times, low match for {', '.join(preferred_genres)})"
                                    movie['genre_match_explanation'] = f"Low confidence matches for {preferred_genres}, showing most booked movies by other users instead"
                                recommendations.extend(most_booked)
                        else:
                            print("[INFO] No booking data available, falling back to general popular movies")
                            # Fallback to general popular movies if no booking data
                            for doc in data.get('documents', [])[:10]:  # Limit to top 10
                                fields = doc.get('fields', {})
                                movie = {
                                    'id': get_field_value(fields.get('id')),
                                    'title': get_field_value(fields.get('title'), 'Unknown'),
                                    'overview': get_field_value(fields.get('overview'), ''),
                                    'poster_path': get_field_value(fields.get('poster_path')) or get_field_value(fields.get('backdrop_path')),
                                    'imageUrl': get_field_value(fields.get('imageUrl')),
                                    'backdrop_path': get_field_value(fields.get('backdropPath')),
                                    'genres': get_field_value(fields.get('genres'), []),
                                    'genre_ids': get_field_value(fields.get('genreIds'), []),
                                    'release_date': get_field_value(fields.get('releaseDate'), ''),
                                    'vote_average': get_field_value(fields.get('voteAverage'), 0),
                                    'popularity': 0,
                                    'runtime': get_field_value(fields.get('runtime'), 0),
                                    'original_language': get_field_value(fields.get('originalLanguage'), ''),
                                    'isFromTMDB': get_field_value(fields.get('isFromTMDB'), False),
                                    'categories': get_field_value(fields.get('categories'), []),
                                    'cinemaBrands': get_field_value(fields.get('cinemaBrands'), []),
                                    'cast': [actor.get('name', '') for actor in get_field_value(fields.get('cast'), [])[:5]] if get_field_value(fields.get('cast')) else []
                                }
                                
                                movie['confidence_percentage'] = 50  # Neutral confidence for popular movies
                                movie['recommendation_reason'] = f"50% match - Popular movie (no exact genre match for {', '.join(preferred_genres)})"
                                movie['genre_match_explanation'] = f"No matches found for {preferred_genres}, showing popular movies"
                            recommendations.append(movie)
                    
                        print(f"[INFO] Added {len(recommendations)} fallback recommendations")
                        
                else:
                    print(f"[ERROR] Failed to fetch movies from database: {response.status_code}")
                    return self._get_mock_movies()
            else:
                print("[ERROR] Firebase not available, using mock data for genre-based recommendations")
                # Use mock data and filter by preferred genres
                mock_movies = self._get_mock_movies()
                for movie in mock_movies:
                    movie_genres = movie.get('genres', [])
                    if any(genre in movie_genres for genre in preferred_genres):
                        # Calculate confidence score for new users (based on genre match)
                        genre_match_score = 0.8 if any(genre in movie_genres for genre in preferred_genres) else 0.6
                        actor_match_score = 0.2 if preferred_actors and any(actor in movie.get('cast', []) for actor in preferred_actors) else 0.0
                        confidence_score = genre_match_score + actor_match_score
                        
                        movie['confidence_percentage'] = self.normalize_similarity_score(confidence_score)
                        
                        # Additional filtering by preferred actors if specified
                        if preferred_actors:
                            if any(actor in movie.get('cast', []) for actor in preferred_actors):
                                movie['recommendation_reason'] = f"{movie['confidence_percentage']}% match - {', '.join([g for g in movie_genres if g in preferred_genres])} movie featuring {', '.join(set(movie.get('cast', [])) & set(preferred_actors))}"
                            else:
                                movie['recommendation_reason'] = f"{movie['confidence_percentage']}% match - {', '.join([g for g in movie_genres if g in preferred_genres])} movie based on your preferences"
                        else:
                            movie['recommendation_reason'] = f"{movie['confidence_percentage']}% match - {', '.join([g for g in movie_genres if g in preferred_genres])} movie based on your preferences"
                        
                        recommendations.append(movie)
                print(f"[SUCCESS] Found {len(recommendations)} genre-based recommendations from mock data")
                return recommendations
                            
        except Exception as e:
            print(f"Error fetching genre-based recommendations: {e}")
            return []
        
        # Remove duplicates and sort by confidence, then vote average
        seen_ids = set()
        unique_recommendations = []
        for movie in recommendations:
            if movie['id'] not in seen_ids:
                seen_ids.add(movie['id'])
                unique_recommendations.append(movie)
        
        # Sort by confidence percentage first, then vote average
        return sorted(unique_recommendations, key=lambda x: (x.get('confidence_percentage', 0), x.get('vote_average', 0)), reverse=True)[:10]

# Initialize recommendation engine
rec_engine = MovieRecommendationEngine()

@app.route("/recommend", methods=["POST"])
def recommend():
    """Main recommendation endpoint"""
    data = request.json
    user_id = data.get('user_id')
    movie_id = data.get('movie_id')  # Optional: for similar movie recommendations
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
    
    try:
        # Get user booking history (from Flutter or Firebase)
        flutter_booking_history = data.get('booking_history')
        booking_history = rec_engine.get_user_booking_history(user_id, flutter_booking_history)
        
        if not booking_history:
            # New user - need preferences
            return jsonify({
                "type": "new_user",
                "message": "No booking history found. Please provide preferences.",
                "available_genres": list(rec_engine.genre_mapping.values())
            })
        
        # Existing user with booking history
        user_profile = rec_engine.create_user_profile(user_id, booking_history)
        watched_movie_ids = rec_engine.get_watched_movie_ids(booking_history)
        
        if movie_id:
            # Get similar movies to the specified movie
            target_movie = rec_engine.fetch_movie_metadata(movie_id)
            if not target_movie:
                return jsonify({"error": "Movie not found"}), 404
            
            # Get candidate movies (popular movies)
            popular_movies = rec_engine.fetch_popular_movies()
            candidate_movies = []
            for movie in popular_movies:
                if movie['id'] != int(movie_id) and str(movie['id']) not in watched_movie_ids:
                    movie_data = rec_engine.fetch_movie_metadata(movie['id'])
                    if movie_data:
                        candidate_movies.append(movie_data)
            
            # Calculate similarities
            similarities = rec_engine.calculate_movie_similarity(target_movie, candidate_movies, user_profile)
            
            # Create recommendations with scores and confidence
            recommendations = []
            for i, movie in enumerate(candidate_movies):
                similarity_score = float(similarities[i])
                movie['similarity_score'] = similarity_score
                movie['confidence_percentage'] = rec_engine.normalize_similarity_score(similarity_score)
                movie['recommendation_reason'] = rec_engine.get_confidence_explanation(similarity_score, user_profile)
                movie['match_explanation'] = f"Similar to {target_movie['title']} based on your viewing history"
                recommendations.append(movie)
            
            # Hybrid sort: similarity first, then popularity
            recommendations = rec_engine.hybrid_sort_recommendations(recommendations, user_profile)
            
            return jsonify({
                "type": "similar_movies",
                "recommendations": recommendations[:10],
                "user_profile": user_profile,
                "excluded_watched": len(watched_movie_ids)
            })
        
        else:
            # General recommendations based on user profile
            # Get popular movies and score them based on user preferences
            popular_movies = rec_engine.fetch_popular_movies()
            recommendations = []
            
            for movie in popular_movies:
                # Skip watched movies
                if str(movie['id']) in watched_movie_ids:
                    continue
                    
                movie_data = rec_engine.fetch_movie_metadata(movie['id'])
                if movie_data:
                    # Calculate preference score
                    genre_score = sum(user_profile['preferred_genres'].get(genre, 0) for genre in movie_data['genres'])
                    actor_score = sum(user_profile['preferred_actors'].get(actor, 0) for actor in movie_data['cast'])
                    
                    total_score = (genre_score + actor_score) / user_profile['total_bookings']
                    movie_data['preference_score'] = float(total_score)
                    movie_data['confidence_percentage'] = rec_engine.normalize_similarity_score(total_score)
                    movie_data['recommendation_reason'] = rec_engine.get_confidence_explanation(total_score, user_profile)
                    movie_data['match_explanation'] = f"Matches your interests in {', '.join(movie_data['genres'][:2])}"
                    
                    recommendations.append(movie_data)
            
            # Hybrid sort: preference score first, then popularity
            recommendations = rec_engine.hybrid_sort_recommendations(recommendations, user_profile)
            
            # Debug: Check if poster_path exists in final recommendations
            final_recommendations = recommendations[:10]
            for i, rec in enumerate(final_recommendations):
                if rec.get('poster_path'):
                    print(f"[SUCCESS] Final rec {i+1}: {rec['title']} HAS poster: {rec['poster_path']} (Confidence: {rec.get('confidence_percentage', 0)}%)")
                else:
                    print(f"[ERROR] Final rec {i+1}: {rec['title']} NO poster! (Confidence: {rec.get('confidence_percentage', 0)}%)")
            
            return jsonify({
                "type": "personalized",
                "recommendations": final_recommendations,
                "user_profile": user_profile,
                "excluded_watched": len(watched_movie_ids)
            })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/recommend/new-user", methods=["POST"])
def recommend_new_user():
    """Recommendations for new users based on preferences"""
    data = request.json
    preferred_genres = data.get('preferred_genres', [])
    preferred_actors = data.get('preferred_actors', [])
    user_id = data.get('user_id')
    
    if not preferred_genres:
        return jsonify({"error": "At least one preferred genre is required"}), 400
    
    try:
        recommendations = rec_engine.get_genre_based_recommendations(preferred_genres, preferred_actors)
        
        return jsonify({
            "type": "new_user_preferences",
            "recommendations": recommendations[:10],
            "user_preferences": {
                "genres": preferred_genres,
                "actors": preferred_actors
            }
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/genres", methods=["GET"])
def get_genres():
    """Get available movie genres"""
    return jsonify({
        "genres": list(rec_engine.genre_mapping.values())
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000, debug=True, threaded=True)
