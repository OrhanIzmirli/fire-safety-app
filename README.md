# 🔥 Fire Safety App

A Flutter-based fire safety mobile application that displays wildfire hotspots in Turkey using NASA FIRMS data, shows nearby emergency/shelter points on the map, provides wind direction information, and supports route navigation + location sharing.

Note: The current UI is in Turkish because the app is designed for local users in Türkiye, where wildfire awareness and response support have become increasingly important.

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

<img width="406" height="849" alt="Home Screen" src="https://github.com/user-attachments/assets/4678f7a3-5621-49bc-8079-582987522aaf" />

---

### Map Overview (Fires + Emergency Points)
Fire hotspots and emergency/shelter points are displayed together on OpenStreetMap.

<img width="381" height="831" alt="{31195784-AEAE-4DED-9C57-0A120FBDEB1A}" src="https://github.com/user-attachments/assets/99361302-4b09-4cf4-99fb-71ee55a14031" />

---

### Map Legend and Marker Colors
The legend explains all marker colors used in the app.

<img width="399" height="845" alt="{0A6710F5-1189-4CE5-A00D-C8F222A02F16}" src="https://github.com/user-attachments/assets/b22c3545-09dc-4da5-aaa3-1828b4f8bcd0" />

---

### Fire Marker Bottom Sheet
Includes:
- Wind direction
- Route options (Driving / Walking)
- Share location

<img width="390" height="840" alt="{1CFFADD5-F0D1-4E4A-A747-83E0B7E4347C}" src="https://github.com/user-attachments/assets/97d74dc8-fbd4-4542-aa05-d7b9d07a901c" />

---

### Shelter / Emergency Point Bottom Sheet
Includes:
- Route options (Driving / Walking)
- Share location

<img width="395" height="846" alt="{88ADF634-F4B9-44E9-A1C8-C3EDE97511FC}" src="https://github.com/user-attachments/assets/f9ba28ea-c2d9-4d1b-ab71-86d1ed8ce1b6" />


---

### Fire Records List Dialog
Fire records are listed from nearest to farthest with address details.

<img width="392" height="835" alt="{E638960D-F4D9-44A3-B67C-0E76CD14EC45}" src="https://github.com/user-attachments/assets/dd4095e0-273c-4064-bfd4-24db81338c61" />


---

### In-App Notification Banner
Example of a fire alert shown inside the app.

<img width="289" height="195" alt="{BEB7A67B-9327-4DB1-BCCF-D37C2B3E5B33}" src="https://github.com/user-attachments/assets/20075bb3-a46e-4b8f-b205-326e8955f244" />

---

### System Notification Example
Example of the local notification shown in Android notification panel.

<img width="395" height="833" alt="{8C0F80E8-83AE-4378-A3A9-726731D2C868}" src="https://github.com/user-attachments/assets/90b6b61d-141e-42f3-8007-c8de766555f2" />

---

### Share Location Sheet
Users can share fire/shelter location via apps like WhatsApp, Telegram, or copy a Maps link.

<img width="393" height="850" alt="{233AD084-4D88-4936-B979-12F6B346DDD1}" src="https://github.com/user-attachments/assets/f3a3b4ac-0225-4e7a-a36e-2b4d84adb465" />


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

## Run with API keys

flutter run --dart-define=FIRMS_MAP_KEY=YOUR_FIRMS_KEY --dart-define=OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY

On Windows PowerShell, you can also run it in one line:

flutter run --dart-define=FIRMS_MAP_KEY=YOUR_FIRMS_KEY --dart-define=OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY

## Notes on Security

- Firebase config files are excluded from version control
- Local secret files are excluded from version control
- API keys are provided via `--dart-define` only

## Future Improvements

- Better UI/UX redesign (planned with frontend collaboration)
- Google Play release version
- Real-time fire alert distance filtering by user location
- Better offline/error fallback UX
- Multi-language support (TR/EN)

## Author

Orhan Izmirli  
Computer Science Student (Poland)  
Project focus: Flutter mobile development, map-based systems, and real-world safety applications.
