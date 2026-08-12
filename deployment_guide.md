# Yabu Supermarket - Production Hosting & Deployment Guide

This guide details step-by-step instructions to host the **Yabu Supermarket Node.js Backend** in the cloud and distribute the compiled **Flutter App (Android APK & Web)**.

---

## 1. Database Setup (MongoDB Atlas - Free Tier)

1. Create a free account at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Create a new Cluster (M0 Free Tier).
3. Under **Database Access**, create a database user (e.g. `admin_user`) and password.
4. Under **Network Access**, click **Add IP Address** and select **Allow Access from Anywhere** (`0.0.0.0/0`).
5. Copy your connection string:
   ```env
   MONGODB_URI=mongodb+srv://admin_user:<password>@cluster0.abcde.mongodb.net/yabusupermarket?retryWrites=true&w=majority
   ```

---

## 2. Hosting the Backend (Option A: Render.com - Free & Easy)

1. Push your repository to GitHub / GitLab.
2. Log into [Render.com](https://render.com) and click **New + -> Web Service**.
3. Connect your GitHub repository and select the `autoparts/backend` folder.
4. Set the following details:
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node src/server.js`
5. Under **Environment Variables**, add:
   - `PORT`: `5000`
   - `NODE_ENV`: `production`
   - `MONGODB_URI`: `<Your MongoDB Atlas Connection String>`
   - `JWT_SECRET`: `<Random 32+ character string>`
   - `JWT_REFRESH_SECRET`: `<Random 32+ character string>`
   - `CLIENT_URL`: `*`
6. Click **Create Web Service**. Render will give you a public URL like:
   `https://yabu-supermarket-api.onrender.com`

---

## 3. Hosting the Backend (Option B: Docker / Railway / DigitalOcean / VPS)

If hosting on Docker, Railway, or VPS:
1. A production `Dockerfile` has been generated at `backend/Dockerfile`.
2. Deploy via Docker:
   ```bash
   docker build -t yabu-backend ./backend
   docker run -d -p 5000:5000 --env-file ./backend/.env yabu-backend
   ```

---

## 4. Building the Production Flutter Apps

### A. Android Release APK
The release APK is generated at:
`flutter_app/build/app/outputs/flutter-apk/app-release.apk`

To connect to your hosted backend URL:
Update `lib/core/constants/app_constants.dart` line 4:
```dart
static const String baseUrl = 'https://yabu-supermarket-api.onrender.com/api';
```
Then build the release APK:
```bash
cd flutter_app
flutter build apk --release
```

### B. Flutter Web App
To build the web bundle:
```bash
cd flutter_app
flutter build web --release
```
The output files in `flutter_app/build/web` can be deployed to Vercel, Netlify, Firebase Hosting, or GitHub Pages!

---

## 5. Admin & Shopkeeper Credentials

- **Admin Account**:
  - Email: `admin@yabusupermarket.com`
  - Password: `Admin@1234`
- **Kebede Branch Shopkeeper**:
  - Email: `kebede@yabusupermarket.com`
  - Password: `Shop@1234`
- **Mekdes Branch Shopkeeper**:
  - Email: `mekdes@yabusupermarket.com`
  - Password: `Shop@1234`
