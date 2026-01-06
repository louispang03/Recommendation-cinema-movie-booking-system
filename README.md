# CINELOOK - Smart Cinema Booking Application 🎬

**CINELOOK** is a cutting-edge mobile application designed to revolutionize the movie-going experience. Built with **Flutter** and powered by advanced **AI technologies**, it offers a seamless journey from movie discovery to ticket booking.

## 🌟 Key Features

### 🤖 AI-Powered Chatbot Assistant
- **Intelligent Conversations**: Integrated with **Dify AI** and **OpenAI** to provide natural, human-like interactions.
- **Movie Discovery**: Ask for recommendations based on mood, genre, or specific actors (e.g., "Recommend a sci-fi movie like Interstellar").
- **Booking Assistance**: Guide users through the booking process directly within the chat interface.
- **Cinema Locator**: Find nearby cinemas and get directions instantly.

### 🎯 Smart Recommendation Engine
- **Hybrid System**: Combines **Content-Based Filtering** (TF-IDF, Cosine Similarity) with **User Preference Learning**.
- **Personalized Suggestions**: Analyzes viewing history, genre preferences, and ratings to curate a unique "For You" list.
- **Real-Time Updates**: Recommendations evolve as you interact with the app.

### 📍 Integrated Cinema Locator
- **Google Maps Integration**: Visual map interface to locate cinemas (GSC, LFS, mmCineplexes) near you.
- **Real-Time Distance**: Calculates precise distance and travel time from your current location.
- **Navigation**: One-tap directions to your chosen cinema.

### 🎟️ Seamless Booking Experience
- **Interactive Seat Selection**: Real-time visualization of available seats.
- **Instant Confirmation**: Secure booking processing with immediate confirmation.
- **QR Code Tickets**: Paperless entry with auto-generated QR codes for easy scanning at the cinema.

### 👥 User-Centric Features
- **Personal Dashboard**: Track booking history, favorite movies, and loyalty points.
- **Smart Notifications**: **OneSignal** integration for booking reminders, new releases, and exclusive promotions.
- **Watchlist**: Save movies you want to see later.

### 🛠️ Powerful Admin Dashboard
- **Analytics & Reporting**: Visual insights into booking trends, revenue, and user engagement.
- **Content Management**: Add, update, or remove movies and showtimes.
- **Customer Support**: Manage feedback and handle ticket cancellation requests efficiently.
- **Broadcast System**: Send system-wide notifications to all users.

---

## 🏗️ Technology Stack

### Frontend
- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: Provider / GetX
- **UI Components**: Custom widgets, Google Fonts, Lottie Animations

### Backend & Database
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage

### AI 
- **Chatbot**: Dify AI Platform, OpenAI API

### External APIs & Services
- **Maps**: Google Maps Platform (Places API, Geocoding API)
- **Movies**: TMDB (The Movie Database) API
- **Notifications**: OneSignal

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Python 3.8+**: For the recommendation engine.
- **Firebase Project**: Set up a project on [Firebase Console](https://console.firebase.google.com/).

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yourusername/fyp_cinema_app.git
    cd fyp_cinema_app
    ```

2.  **Install Flutter Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Configure Environment Variables**
    - Create a `.env` file in the root directory:
      ```env
      # Add your keys here
      ONESIGNAL_APP_ID=your_onesignal_id
      ```
    - Create a `movie_api.env` file:
      ```env
      TMDB_API_KEY=your_tmdb_key
      ```

4.  **Setup Firebase**
    - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from Firebase Console.
    - Place them in `android/app/` and `ios/Runner/` respectively.

5.  **Run the Recommendation Engine**
    ```bash
    cd recommendation-cinema-movie-booking-system
    pip install -r requirements.txt
    python recommendation_engine.py
    ```

6.  **Run the App**
    ```bash
    flutter run
    ```

---

## 📸 Screenshots

| Login Screen | 

<img width="825" height="587" alt="image" src="https://github.com/user-attachments/assets/d5e140f7-b09e-470e-87b2-403de9a4e7a9" />


| Home Screen | 

<img width="637" height="548" alt="image" src="https://github.com/user-attachments/assets/bc4cfe73-d1f3-4938-95db-372372371c07" />



| Movie Screen |

<img width="733" height="676" alt="image" src="https://github.com/user-attachments/assets/eebfd293-37be-4a90-9330-dc38728d6064" />



| F&B Screen |

<img width="762" height="627" alt="image" src="https://github.com/user-attachments/assets/42a7b2d1-d61a-4579-8659-919f797f29fc" />


<img width="814" height="630" alt="image" src="https://github.com/user-attachments/assets/f42329ad-2fa4-4b10-9d41-7f73eb36b7d1" />



| User Profile Screen |

<img width="676" height="662" alt="image" src="https://github.com/user-attachments/assets/4a92d58b-64a2-4d0e-b61a-394e0bca27d6" />



|Feedback Screen |

<img width="576" height="583" alt="image" src="https://github.com/user-attachments/assets/e8a41478-2757-4ce7-8878-d772a1158d3c" />


| Booking History |

<img width="608" height="609" alt="image" src="https://github.com/user-attachments/assets/eeeffd10-08a8-48b8-8afc-a9b39b1b369d" />


| Movie Details Page |

<img width="591" height="616" alt="image" src="https://github.com/user-attachments/assets/03cc9c39-3043-40a3-847b-ffbdf5f06707" />


| Seat Selection |

<img width="606" height="518" alt="image" src="https://github.com/user-attachments/assets/64eb1eaf-15b1-4d46-b7a2-ff8d7c089bb7" />


<img width="600" height="428" alt="image" src="https://github.com/user-attachments/assets/df6c15a6-b02d-43a5-98b6-e0166bf5385f" />


<img width="626" height="435" alt="image" src="https://github.com/user-attachments/assets/8bb5fad3-e46a-47ca-b8df-635eddd9203b" />


| Cinema Locator Screen |

<img width="531" height="502" alt="image" src="https://github.com/user-attachments/assets/050fc218-3b3d-4f3f-badd-856b5cf9c47e" />


| Chatbot |


<img width="258" height="546" alt="image" src="https://github.com/user-attachments/assets/5b75c8b6-8f0a-4993-ab1f-5fb1e007741c" />


| Recomendation Screen |


<img width="584" height="539" alt="image" src="https://github.com/user-attachments/assets/79b11995-e7dd-46d4-86f6-21bf2645ec5d" />


| Admin Screen |


<img width="451" height="475" alt="image" src="https://github.com/user-attachments/assets/5d8b3fd3-0fb4-4fea-a931-5ccd5c12cb17" />



| Analytics Overview Screen |


<img width="509" height="532" alt="image" src="https://github.com/user-attachments/assets/1f4223fc-d43b-4373-996f-c884e0a8ed05" />






