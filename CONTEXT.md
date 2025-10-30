

✅ MoodMusic App — Core Feature Requirements

⸻

🔧 1. Tech Stack

Layer	Stack
Frontend	SwiftUI (iOS only for now)
Backend	Optional: Firebase / Supabase for user + mood data
ML/AI	On-device or server-based face emotion detection
APIs	Spotify API + Event API (e.g., Ticketmaster/Eventbrite)


⸻

🧠 2. Core Features Breakdown

2.1 Face Emotion Detection
	•	Use Apple’s Vision Framework for on-device emotion recognition (basic)
	•	Or use Microsoft Azure Face API / Affectiva SDK for higher emotion precision
	•	Extract mood categories: ["Happy", "Sad", "Angry", "Calm", "Anxious", "Excited"]

2.2 Spotify Integration
	•	Register with Spotify Developer Dashboard
	•	Use OAuth 2.0 to authenticate user
	•	Required scopes: user-read-private, user-read-email, user-top-read, user-read-playback-state, app-remote-control, streaming
	•	Get song or playlist suggestions based on:
	•	Mood keyword → genre mapping
	•	Tempo / valence (from Spotify audio features)

2.3 Local Event Suggestions
	•	Use APIs like:
	•	Ticketmaster Discovery API
	•	Eventbrite Public API
	•	Geo-filter events based on location + mood type

2.4 User Interface
	•	Start screen with background + “Start Mood Scan”
	•	Face scanner with facial outline UI
	•	Mood Result page with:
	•	Mood icon/title
	•	Suggested track (with album art + play button)
	•	Event suggestion block
	•	Paywall modal (optional)

⸻

🗂️ 3. App Content & Data Models

3.1 Mood Mapping Logic

let moodToGenre: [String: [String]] = [
  "Happy": ["pop", "dance", "disco"],
  "Sad": ["acoustic", "piano", "ambient"],
  "Angry": ["metal", "rock", "hardcore"],
  "Calm": ["classical", "chill", "lofi"],
  "Anxious": ["ambient", "meditation", "soft rock"],
  "Excited": ["edm", "hip-hop", "trap"]
]

3.2 User Data Model

struct UserProfile {
    var id: String
    var spotifyAccessToken: String
    var moods: [MoodEntry]
}

struct MoodEntry {
    var date: Date
    var mood: String
    var songID: String
    var location: String
}


⸻

⚙️ 4. Must-Have External Dependencies
	•	Spotify iOS SDK: Spotify iOS SDK (Apple Docs)
	•	Facial Emotion Detection: Apple Vision / Azure Face API / Affectiva
	•	Location Access: CoreLocation
	•	Optionally: Firebase for login, data, storage

⸻

📦 Next Steps
	1.	Scaffold app with SwiftUI + onboarding screen
	2.	Implement Spotify Auth + basic fetch for top tracks
	3.	Add camera access + stub mood classification (mock it if no API yet)
	4.	Connect mood → song + event results
	5.	Build UI around flow
	6.	(Optional) Store history and allow mood review

