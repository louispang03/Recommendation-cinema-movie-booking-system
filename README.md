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

<img width="787" height="572" alt="image" src="https://github.com/user-attachments/assets/fd65e4bc-f67e-45da-a1cb-30862cc4bc42" />


| Home Screen | 

<img width="609" height="550" alt="image" src="https://github.com/user-attachments/assets/6a6f4da4-e269-44af-883a-20a8d1262dcd" />


| Movie Screen |

<img width="670" height="630" alt="image" src="https://github.com/user-attachments/assets/ec24879f-125f-47fd-b0ae-238ba4156161" />


| F&B Screen |

<img width="677" height="602" alt="image" src="https://github.com/user-attachments/assets/5fb58255-ce61-4f63-a208-7405aa9ddcde" />

<img width="709" height="544" alt="image" src="https://github.com/user-attachments/assets/1c80b9dd-4b2a-4cd7-9eba-4c2fa015340b" />


| User Profile Screen |

<img width="600" height="581" alt="image" src="https://github.com/user-attachments/assets/80853286-3353-4e2d-a064-f52a64c87dce" />


|Feedback Screen |

<img width="507" height="498" alt="image" src="https://github.com/user-attachments/assets/d42eb32d-c912-4aa5-8320-c6e0450310eb" />

| Booking History |

<img width="707" height="725" alt="image" src="https://github.com/user-attachments/assets/c7cca68c-daf3-4a4f-843b-2169bf506fbc" />

| Movie Details Page |

<img width="502" height="590" alt="image" src="https://github.com/user-attachments/assets/72f13a3f-d023-45e1-94dd-f472478250cc" />

| Seat Selection |

<img width="523" height="440" alt="image" src="https://github.com/user-attachments/assets/66f2e2d5-fad7-4f4d-b5b3-cad7b16900ad" />


<img width="535" height="386" alt="image" src="https://github.com/user-attachments/assets/015e29b3-efdf-4993-9595-cee5301603e0" />


<img width="550" height="394" alt="image" src="https://github.com/user-attachments/assets/e165afdf-4c3b-44c1-91cb-8d0a109f1757" />


| Cinema Locator Screen |

<img width="480" height="457" alt="image" src="https://github.com/user-attachments/assets/ea054a32-96ab-45a4-a702-9871b2e54b11" />


| Chatbot |


<img width="245" height="486" alt="image" src="https://github.com/user-attachments/assets/00ef0de4-08da-46bc-9f2f-c8bf7da01c51" />


| Recomendation Screen |


<img width="514" height="485" alt="image" src="https://github.com/user-attachments/assets/eae226e2-d6f5-438a-a987-142c5d61d410" />


| Admin Screen |


<img width="410" height="432" alt="image" src="https://github.com/user-attachments/assets/dcee5972-e25d-43f9-a664-96e38ff56d5f" />


| Analytics Overview Screen |


<img width="476" height="487" alt="image" src="https://github.com/user-attachments/assets/36cb4ac7-293e-41cc-965f-bc3bc5151e04" />





