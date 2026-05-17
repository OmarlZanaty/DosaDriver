# 🚀 DosaDriver — Zero-to-Hero EC2 Installation Guide

## PART 1 — Server Setup

### 1.1 Connect & Update
```bash
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget unzip build-essential
```

### 1.2 Install Docker
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu && newgrp docker
docker --version && docker compose version
```

### 1.3 Install Node.js 20
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs && node --version
```

## PART 2 — Deploy Backend

### 2.1 Upload code
```bash
# LOCAL machine:
scp -i your-key.pem -r dosadriver_production/ ubuntu@YOUR_EC2_IP:/home/ubuntu/dosadriver/
```

### 2.2 Configure environment
```bash
cd /home/ubuntu/dosadriver/docker
cp .env.production .env
nano .env  # Fill in passwords, Firebase SA, domain
```

### 2.3 Encode Firebase service account
```bash
base64 -w 0 serviceAccount.json.json
# Paste output into FIREBASE_SERVICE_ACCOUNT in .env
```

### 2.4 Update domain in nginx.conf
```bash
sed -i 's/yourdomain.com/YOUR_REAL_DOMAIN/g' nginx.conf
```

### 2.5 Start all services
```bash
cd /home/ubuntu/dosadriver/docker
docker compose --env-file .env up -d
docker compose logs -f api  # Watch logs
```

### 2.6 SSL Certificate
```bash
sudo apt install -y certbot
sudo certbot certonly --standalone -d yourdomain.com \
  --email admin@yourdomain.com --agree-tos --non-interactive
docker compose exec nginx nginx -s reload
# Auto-renew:
echo "0 3 * * * certbot renew --quiet && docker exec dosadriver-nginx nginx -s reload" | sudo crontab -
```

### 2.7 Verify
```bash
curl https://yourdomain.com/v1/health
# Expected: {"status":"ok"}
```

## PART 3 — Set Captain Roles

```bash
# After captain registers, set Custom Claim (admin must do this):
docker exec -it dosadriver-api node -e "
const admin = require('firebase-admin');
const sa = JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT,'base64').toString());
admin.initializeApp({credential: admin.credential.cert(sa)});
admin.auth().setCustomUserClaims('CAPTAIN_UID_HERE', {role:'CAPTAIN'})
  .then(()=>{console.log('Done! Captain must re-login.');process.exit(0);});
"
```

## PART 4 — Build Flutter Apps

### 4.1 Captain APK
```bash
cd captain-fixed/
flutter pub get
# Place android/app/google-services.json (package: com.dosadriver.captain)
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### 4.2 Client APK
```bash
cd client-fixed/
flutter pub get
# Place android/app/google-services.json (package: com.dosadriver.client)
flutter build apk --release
```

### 4.3 Admin Dashboard (Flutter Web)
```bash
cd admin-fixed/
flutter pub get
flutter build web --release
# Deploy build/web/ to EC2 or Firebase Hosting
```

## PART 5 — Firestore Security Rules

In Firebase Console > Firestore > Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rides/{rideId} {
      allow read: if request.auth != null &&
        (resource.data.riderId == request.auth.uid ||
         resource.data.captainUid == request.auth.uid);
      allow write: if false; // Backend service account only
    }
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /drivers/{uid} {
      allow read:  if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /captains_live/{uid} {
      allow read:  if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /ride_ratings/{id} {
      allow create: if request.auth != null;
      allow read:   if request.auth != null;
    }
  }
}
```

## PART 6 — API Key Security (IMPORTANT)

In Google Cloud Console > APIs & Services > Credentials > your key:
- Restrict to Android apps: add package names + SHA-1 fingerprints
  - com.dosadriver.captain
  - com.dosadriver.client
- Restrict APIs to: Maps SDK, Geocoding API, Directions API

## PART 7 — Maintenance

```bash
# Logs
docker compose logs -f api

# Restart after update
docker compose build api && docker compose up -d api

# DB backup
docker exec dosadriver-postgres pg_dump -U dosadriver dosadriver > backup_$(date +%F).sql

# Run migrations
docker exec dosadriver-api npx prisma migrate deploy
```

## Checklist

- [ ] API health endpoint returns OK
- [ ] Firebase Auth works (phone+password)
- [ ] Captain sees open rides
- [ ] Full ride lifecycle works end-to-end
- [ ] Transfer payment: client uploads proof, captain confirms
- [ ] SSL certificate valid
- [ ] Firestore security rules deployed
- [ ] Captain role set via Firebase Custom Claims
- [ ] Google Maps API key restricted
