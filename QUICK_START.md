# NeuralNT Quick Start Guide

## Fastest Way to Get Running (5 minutes)

### 1. Start Backend (Terminal 1)
```powershell
cd d:\projeks\internship\P2\NNT2\NeuralNT
python backend_api.py
```
✅ Wait for: `Uvicorn running on http://0.0.0.0:8000`

### 2. Start Frontend (Terminal 2)
```powershell
cd d:\projeks\internship\P2\NNT2\NeuralNT\frontend
flutter run
```
✅ Wait for app to appear on emulator/device

### 3. Test the Connection
- Look at the **top-right** of the app
- Should show: **"API Ready"** (green)
- If showing "No API" or "Offline", check backend is running

---

## What to Do Next?

### Option A: Use Built-in Dataset (Easiest)
1. Go to **Train tab**
2. Download any public dataset (CIFAR-10, MNIST, etc.) as ZIP
3. Click "Select Dataset"
4. Click **START TRAINING**

### Option B: Create Custom Dataset
1. Create folder: `my_dataset/`
2. Create subfolders for each class:
   ```
   my_dataset/
   ├── dogs/
   │   ├── dog1.jpg
   │   └── dog2.jpg
   └── cats/
       ├── cat1.jpg
       └── cat2.jpg
   ```
3. ZIP the folder: `my_dataset.zip`
4. Upload in app

---

## Common Commands

### Reset Everything
```powershell
# Backend
Ctrl + C  # Stop backend

# Frontend
flutter clean
flutter pub get
flutter run
```

### Check Backend Health
Open browser: `http://localhost:8000/health`  
Should return: `{"status":"ok", "timestamp":"2026-03-23T..."}`

### Check Firewall
```powershell
# Allow port 8000 (Windows)
netsh advfirewall firewall add rule name="NeuralNT API" dir=in action=allow protocol=tcp localport=8000
```

---

## If Using Physical Phone

1. Get your PC IP:
   ```powershell
   ipconfig
   ```
   Look for IPv4 address (e.g., `192.168.1.100`)

2. Edit `frontend/lib/main.dart` line 118:
   ```dart
   baseUrl = "http://192.168.1.100:8000";
   ```

3. Connect phone to same WiFi

4. Run:
   ```powershell
   flutter run
   ```

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `R` | Hot reload (Flutter) |
| `Ctrl+C` | Stop backend/app |
| `Q` | Quit Flutter |

---

## API Base URLs

| Device | URL | Backend Requirement |
|--------|-----|---|
| Android Emulator | `10.0.2.2:8000` | Running on PC |
| Android Phone | `[PC_IP_ADDRESS]:8000` | Same WiFi network |
| iOS/Windows | `localhost:8000` | Running on same PC |

---

## File Sizes

Keep dataset ZIP under 500MB for smooth training on mobile.

---

## Still Have Issues?

See `MOBILE_SETUP_GUIDE.md` for detailed troubleshooting.
