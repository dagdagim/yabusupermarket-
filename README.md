# 🛒 Yabu Supermarket — Smart Inventory & Sales Management System

A full-stack mobile + backend system for managing supermarket inventory and sales across multiple shops, with real-time dashboard and Barcode/QR-based product management and sales recording.

---

## 📁 Project Structure

```
autoparts/
├── backend/               # Node.js + Express API
│   ├── src/
│   │   ├── config/        # Database config
│   │   ├── controllers/   # Auth, Products, Sales, Users, Reconciliation, Reports
│   │   ├── middleware/    # Auth, Error handling
│   │   ├── models/        # User, Shop, Product, Sale, Reconciliation
│   │   ├── routes/        # All API routes
│   │   ├── services/      # Business logic services
│   │   └── utils/         # JWT, Logger, Seed
│   ├── .env.example
│   ├── Dockerfile
│   └── package.json
│
└── flutter_app/           # Flutter Mobile App
    └── lib/
        ├── core/          # Constants, Theme
        ├── data/          # Models, API service, Repositories
        ├── presentation/
        │   ├── providers/ # Riverpod state management
        │   ├── screens/   # Auth, Admin, Shopkeeper, Shared screens
        │   └── widgets/   # Reusable UI components
        ├── router.dart    # go_router navigation
        └── main.dart      # App entry point
```

---

## 🚀 Backend Setup

### 1. Prerequisites
- Node.js 18+
- MongoDB Atlas account or local MongoDB

### 2. Install & Configure
```bash
cd backend
npm install

cp .env.example .env
# Edit .env with your MongoDB URI and JWT secrets
```

### 3. Seed the database
```bash
npm run seed
```
This creates:
- **Admin**: `admin@yabusupermarket.com` / `Admin@1234`
- **Shopkeeper 1**: `kebede@yabusupermarket.com` / `Shop@1234` → Yabu Supermarket - Main
- **Shopkeeper 2**: `mekdes@yabusupermarket.com` / `Shop@1234` → Yabu Supermarket - Branch 2
- Supermarket products with EAN/Barcodes and QR codes

### 4. Run
```bash
npm run dev       # development (nodemon)
npm start         # production
```

API will be live at: `http://localhost:5000`

### 5. Docker (production)
```bash
docker build -t autoparts-api .
docker run -p 5000:5000 --env-file .env autoparts-api
```

---

## 📱 Flutter App Setup

### 1. Prerequisites
- Flutter 3.16+
- Android Studio / Xcode
- Android emulator or physical device

### 2. Install dependencies
```bash
cd flutter_app
flutter pub get
```

### 3. Configure API URL
Edit `lib/core/constants/app_constants.dart`:

```dart
// For Android Emulator:
static const String baseUrl = 'http://10.0.2.2:5000/api';

// For physical device (same WiFi):
static const String baseUrl = 'http://192.168.x.x:5000/api';

// For production:
static const String baseUrl = 'https://your-domain.com/api';
```

### 4. Android permissions (already set)
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### 5. Run
```bash
flutter run
```

---

## 🔑 API Reference

### Auth
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | `/api/auth/login` | Public | Login |
| POST | `/api/auth/refresh` | Public | Refresh token |
| POST | `/api/auth/logout` | Private | Logout |
| GET | `/api/auth/me` | Private | Current user |
| PUT | `/api/auth/change-password` | Private | Change password |

### Products
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/products` | Private | List products (paginated) |
| GET | `/api/products/:id` | Private | Get product |
| GET | `/api/products/qr/:qrData` | Private | Get by QR code |
| GET | `/api/products/low-stock` | Private | Low stock list |
| POST | `/api/products` | Admin | Create + auto QR |
| PUT | `/api/products/:id` | Admin | Update |
| DELETE | `/api/products/:id` | Admin | Soft delete |
| POST | `/api/products/:id/qr` | Admin | Regenerate QR |

### Sales
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | `/api/sales` | Private | Record sale |
| GET | `/api/sales` | Private | List sales |
| GET | `/api/sales/:id` | Private | Get sale |
| GET | `/api/sales/summary/today` | Admin | Today's summary |
| GET | `/api/sales/analytics` | Admin | Weekly/monthly analytics |

### Reconciliation
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | `/api/reconciliation/generate` | Admin | Generate for shop/date |
| GET | `/api/reconciliation` | Admin | List all |
| GET | `/api/reconciliation/today` | Admin | Today's summary |
| PUT | `/api/reconciliation/:id` | Admin | Update cash received |

### Reports
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/reports` | Admin | Report data |
| GET | `/api/reports/export/excel` | Admin | Download Excel |
| GET | `/api/reports/export/pdf` | Admin | Download PDF |

### Users & Shops
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | `/api/users/shops` | Private | List shops |
| POST | `/api/users/shops` | Admin | Create shop |
| PUT | `/api/users/shops/:id` | Admin | Update shop |
| GET | `/api/users` | Admin | List users |
| POST | `/api/users` | Admin | Create user |
| PUT | `/api/users/:id/toggle-status` | Admin | Activate/deactivate |

---

## ⚡ Real-Time (Socket.IO)

The backend emits events via Socket.IO:

```javascript
// Admin connects
socket.emit('join-admin');

// Events received:
socket.on('new-sale', (data) => { /* { sale, shopId, shopName } */ });
socket.on('low-stock-alert', (data) => { /* { productId, productName, quantity } */ });
```

---

## 🔐 Security Features
- JWT access tokens (7d) + refresh tokens (30d)
- bcrypt password hashing (salt rounds: 12)
- Helmet.js HTTP security headers
- CORS configured
- Rate limiting (200 req/15min global, 20/15min for login)
- Role-based access control (Admin / Shopkeeper)
- Soft deletes (data is never permanently removed)

---

## 🧩 Key Features

### QR Code Flow
1. Admin creates product → QR code auto-generated (base64 PNG)
2. Print/display QR on product
3. Shopkeeper opens app → scans QR
4. Product fetched instantly
5. Confirm quantity → sale recorded
6. Stock decrements automatically
7. Admin dashboard updates in real-time

### End-of-Day Reconciliation
1. Admin generates reconciliation for each shop
2. System calculates expected cash from all completed sales
3. Admin records actual cash received
4. Difference highlighted (overage/shortage)
5. Mark as Verified → Completed

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x + Riverpod + go_router |
| Backend | Node.js + Express.js |
| Database | MongoDB Atlas + Mongoose |
| Auth | JWT + Refresh Tokens + bcrypt |
| Real-time | Socket.IO |
| QR | qrcode (backend) + mobile_scanner (Flutter) |
| Reports | ExcelJS + PDFKit |
| Logging | Winston |
| Security | Helmet + express-rate-limit |

---

## 🚧 Extending the App

The following screens are scaffolded but need full UI implementation:
- `Add/Edit Product` form (`/admin/products/add`)
- `Product Detail` screen (with QR display & print)
- `Users Management` screen
- `Reports` tab with charts (fl_chart is already added)
- `Notifications` screen

These are straightforward to build following the patterns already established in the codebase.

---

## 📋 Environment Variables

```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb+srv://...
JWT_SECRET=min_32_char_secret
JWT_EXPIRE=7d
JWT_REFRESH_SECRET=another_min_32_char_secret
JWT_REFRESH_EXPIRE=30d
CLIENT_URL=http://localhost:3000
```
