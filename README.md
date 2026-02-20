# 🔥 Fire Safety App

A Flutter-based fire safety mobile application that displays wildfire hotspots in Turkey using NASA FIRMS data, shows nearby emergency/shelter points on the map, provides wind direction information, and supports route navigation + location sharing.

---

##  Features

### 1) Fire Detection Data (NASA FIRMS)
- Fetches recent fire hotspot data from **NASA FIRMS**
- Filters results for **Turkey**
- Supports showing fire records as:
  - **List view** (nearest to farthest)
  - **Map markers**

### 2) Smart Shelter & Emergency Points (OpenStreetMap / Overpass)
- Displays nearby emergency-related locations:
  - 🏥 Hospital
  - 🚒 Fire Station
  - 👮 Police
  - 💊 Pharmacy
  - 🏫 School
  - 🟢 Shelter / Safe Point
- Uses optimized requests (lighter query parameters) to reduce timeout/504 errors
- Includes fallback logic for demo usage

### 3) Fire Marker Action Panel
When the user taps a fire marker:
- 🌬️ Wind direction is fetched (OpenWeather)
- 🚗 Route navigation (driving)
- 🚶 Route navigation (walking)
- 📤 Share fire location (Google Maps link)

### 4) Shelter Marker Action Panel
When the user taps a shelter/emergency marker:
- 🚗 Route navigation (driving)
- 🚶 Route navigation (walking)
- 📤 Share location (WhatsApp/Telegram compatible)

### 5) Map Legend
- A built-in legend explains marker colors on the map
- Helps users quickly understand fire and emergency point categories

### 6) Notifications
- Firebase Cloud Messaging support
- Local notification display for fire alerts
- Periodic fire checks (timer-based)

---

## App Screenshots

### Home Screen
Main entry screen with 3 primary actions:
- Report Fire
- Fetch Fire Data
- Show on Map

![Home Screen](assets/readme/home-screen.png)

---

### Map Overview (Fires + Emergency Points)
Fire hotspots and emergency/shelter points are displayed together on OpenStreetMap.

![Map Overview](assets/readme/map-overview.png)

---

### Map Legend and Marker Colors
The legend explains all marker colors used in the app.

![Legend and Markers](assets/readme/legend-and-markers.png)

---

### Fire Marker Bottom Sheet
Includes:
- Wind direction
- Route options (Driving / Walking)
- Share location

![Fire Bottom Sheet](assets/readme/fire-bottom-sheet.png)

---

### Shelter / Emergency Point Bottom Sheet
Includes:
- Route options (Driving / Walking)
- Share location

![Shelter Bottom Sheet](assets/readme/shelter-bottom-sheet.png)

---

### Fire Records List Dialog
Fire records are listed from nearest to farthest with address details.

![Fire List Dialog](assets/readme/fire-list-dialog.png)

---

### In-App Notification Banner
Example of a fire alert shown inside the app.

![Notification Banner](assets/readme/notification-banner.png)

---

### System Notification Example
Example of the local notification shown in Android notification panel.

![System Notification](assets/readme/notification-system.png)

---

### Share Location Sheet
Users can share fire/shelter location via apps like WhatsApp, Telegram, or copy a Maps link.

![Sharing Sheet](assets/readme/sharing-sheet.png)

---

## Tech Stack

- **Flutter**
- **Dart**
- **NASA FIRMS API**
- **OpenStreetMap (flutter_map)**
- **Overpass API**
- **OpenWeather API** (wind direction)
- **Geolocator**
- **Firebase Cloud Messaging**
- **Flutter Local Notifications**
- **url_launcher**
- **share_plus**

---

## Setup (Important)

This project uses runtime keys via `--dart-define` and does **not** store API keys in source code.

### 1) Install dependencies
```bash

flutter pub get
2) Run with API keys
flutter run \
  --dart-define=FIRMS_MAP_KEY=YOUR_FIRMS_KEY \
  --dart-define=OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY

On Windows PowerShell, you can also run it in one line:

flutter run --dart-define=FIRMS_MAP_KEY=YOUR_FIRMS_KEY --dart-define=OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY
🔐 Notes on Security

Firebase config files are excluded from version control

Local secret files are excluded from version control

API keys are provided via --dart-define only

🚀 Future Improvements

Better UI/UX redesign (planned with frontend collaboration)

Google Play release version

Real-time fire alert distance filtering by user location

Better offline/error fallback UX

Multi-language support (TR/EN)

👤 Author

Orhan Izmirli
Computer Science Student (Poland)
Project focus: Flutter mobile development, map-based systems, and real-world safety applications.
