# DosaDriver Client App — Production Setup & Compatibility Report

## ✅ Cross-App Compatibility Analysis

### 1. Firebase Project
- **Same Firebase project** as Captain app: `dosadriver` (project number: `1056710019958`)
- Client registers users with `role: RIDER` in Firestore `users` collection
- Captain uses `role: CAPTAIN` — **no conflict**
- Both apps share the same `rides` Firestore collection for real-time sync

### 2. Backend API Compatibility
| Endpoint | Method | Used By | Notes |
|---|---|---|---|
| `POST /v1/rides` | Client ✅ | createRide() | Sends pickupLat/Lng, dropLat/Lng, type, addresses |
| `GET /v1/rides/active` | Client ✅ | getActiveRide() | Returns current REQUESTED/ACCEPTED/STARTED ride |
| `POST /v1/rides/:id/cancel` | Client ✅ | cancelRide() | Rider cancels ride |
| `GET /v1/rides/open` | Captain ✅ | listOpenRides() | Captain sees REQUESTED rides |
| `POST /v1/rides/:id/accept` | Captain ✅ | acceptRide() | Captain accepts |
| `POST /v1/rides/:id/arrive` | Captain ✅ | captainArrive() |  |
| `POST /v1/rides/:id/start` | Captain ✅ | captainStart() |  |
| `POST /v1/rides/:id/complete` | Captain ✅ | captainComplete() |  |

### 3. Firestore Collections Used
| Collection | Writer | Reader |
|---|---|---|
| `users` | Client Auth (RIDER role) | Backend FirebaseAuthGuard |
| `drivers` | Captain App | Client (reads captain name/phone/rating) |
| `rides` | Client (createRide mirrors) | Captain (live updates) + Client (status polling) |
| `captains_live` | Captain (location updates) | Client (map tracking) |
| `ride_ratings` | Client | Analytics |

### 4. Ride Status Flow
```
Client creates ride → REQUESTED
     ↓
Captain sees ride, accepts → ACCEPTED  (client sees captain on map)
     ↓
Captain arrives at pickup → ARRIVED   (client notified)
     ↓
Captain starts trip → STARTED         (client sees trip in progress)
     ↓
Captain completes trip → COMPLETED    (client goes to rating screen)
```

### 5. Captain Live Location
- Captain writes lat/lng to `captains_live/{captainUid}` document
- Client `ClientActiveRideScreen` listens to this document in real time
- Client draws route from captain → pickup (when ACCEPTED) or captain → destination (when STARTED)

---

## 🚀 Build & Setup Instructions

### Step 1 — Get google-services.json
```
1. Go to Firebase Console → Project: dosadriver
2. Add Android App → Package: com.dosadriver.client
3. Download google-services.json
4. Replace android/app/google-services.json with the downloaded file
```

### Step 2 — Install Flutter dependencies
```bash
cd dosadriver_client
flutter pub get
```

### Step 3 — Build release APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Step 4 — Firestore Security Rules
Add these rules to Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can read/write their own doc
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    // Rides: rider can create, read, and cancel their own rides
    match /rides/{rideId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null &&
        (resource.data.riderId == request.auth.uid ||
         resource.data.captainUid == request.auth.uid);
      allow update: if request.auth != null &&
        (resource.data.riderId == request.auth.uid ||
         resource.data.captainUid == request.auth.uid);
    }

    // Drivers: anyone authenticated can read (for name/phone/rating)
    match /drivers/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }

    // Captain live location: authenticated users can read
    match /captains_live/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }

    // Ratings: rider can write, anyone can read
    match /ride_ratings/{ratingId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```

### Step 5 — Firestore Indexes
Create these composite indexes in Firebase Console → Firestore → Indexes:

```
Collection: rides
Fields: riderId (ASC), createdAt (DESC)
Query scope: Collection
```

---

## 🧪 Full Integration Test Plan

### Test 1: Registration & Login
1. Open client app → Sign up with email + name + phone
2. Check Firebase Auth console — user created ✓
3. Check Firestore `users/{uid}` — role=RIDER ✓
4. Sign out → Sign in again ✓

### Test 2: Booking a Ride
1. Login to client app
2. Allow location permission
3. Tap search bar → enter destination address
4. Select ride type (e.g., FAIR_VALUE)
5. Confirm booking
6. Check Firestore `rides` collection — new doc with status=REQUESTED ✓
7. Check backend API — ride exists in Postgres ✓

### Test 3: Captain Accepts
1. Open Captain app → go online
2. Captain sees ride in list
3. Captain accepts ride
4. Client app shows status=ACCEPTED with captain on map ✓
5. Check `rides/{id}` — captainUid set ✓

### Test 4: Full Ride Lifecycle
```
Captain: arrive → Client shows "captain arrived"   ✓
Captain: start  → Client shows "trip in progress"  ✓
Captain: complete → Client goes to rating screen    ✓
Client rates → rating saved to Firestore            ✓
```

### Test 5: Cancel Ride
1. Client books ride (status=REQUESTED)
2. Client taps "إلغاء الرحلة" → confirms
3. Backend updates status=CANCELED
4. Captain sees ride removed from list ✓
5. Client redirected to home ✓

### Test 6: App Restart Mid-Ride
1. Client books ride
2. Close and reopen client app
3. App should detect active ride → go directly to tracking screen ✓

---

## ⚠️ Important Production Checklist

- [ ] Replace `google-services.json` with real Firebase client file
- [ ] Replace Google Maps API Key in `AndroidManifest.xml` with production key
- [ ] Enable Google Maps API, Geocoding API, Directions API in GCP Console
- [ ] Add `com.dosadriver.client` to Firebase Auth authorized domains
- [ ] Set Firestore security rules (above)
- [ ] Create Firestore composite index for rides query
- [ ] Test on physical Android device (GPS accuracy)
- [ ] Set up FCM for push notifications
- [ ] Configure backend `ALLOWED_ORIGINS` to accept client requests

---

## 📱 App Information

| Field | Value |
|---|---|
| App Name | DosaDriver — تطبيق العميل |
| Package ID | `com.dosadriver.client` |
| Min SDK | 26 (Android 8.0) |
| Target SDK | 35 |
| Version | 1.0.0+1 |
| Backend | `https://dosadriver-api-1056710019958.me-central1.run.app` |
| Firebase Project | `dosadriver` |
| Maps API Key | `AIzaSyC7NK0DvIa47HVqJdiy6sxymGeawr6it8Y` |
