# NeuralNT Mobile Integration Guide

**Version**: 2.0 (Mobile-Ready)  
**Updated**: March 2026

## Overview

NeuralNT is now fully configured as a **FastAPI backend + Flutter mobile application**. This guide explains the complete setup, architecture, and deployment instructions.

---

## Architecture

```
NeuralNT Project
├── Backend (Python)          [Runs on Windows/Linux PC]
│   ├── backend_api.py        [FastAPI Server]
│   ├── model_builder.py
│   ├── training.py
│   ├── validation.py
│   ├── layers.py
│   └── [Other modules]
│
└── Frontend (Flutter)        [Mobile App]
    ├── lib/main.dart         [Main Flutter App]
    └── And roidManifest.xml  [Permissions & Network Config]
```

---

## Part 1: Backend Setup (Python)

### Prerequisites

- **Python 3.9+** installed
- **pip** package manager

### Step 1: Install Dependencies

Open PowerShell in the project root (`d:\projeks\internship\P2\NNT2\NeuralNT\`) and run:

```powershell
# Install PyTorch (CPU version recommended for laptops)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install all other dependencies
pip install -r requirements.txt
```

### Step 2: Start the Backend Server

```powershell
python backend_api.py
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

The server is now running on **`http://localhost:8000`**.

### API Endpoints Available

#### Health & Status
- `GET /health` - Check if server is running
- `GET /status` - Get system status (device, torch version, model exists)
- `GET /training-status` - Get current training progress

#### Architecture Management
- `GET /architecture` - Get current model layers
- `POST /add_layer` - Add a new layer (requires JSON body)
- `POST /reset` - Reset all layers

#### Model Training
- `POST /train` - Start training with ZIP dataset (multipart form-data)

#### Model Testing
- `POST /predict` - Run inference on single image
- `POST /batch-predict` - Run inference on multiple images

---

## Part 2: Frontend Setup (Flutter)

### Prerequisites

- **Flutter SDK 3.0+**
- **Android Studio** with Android SDK 34+ and emulator/device
- **Java 17+**

### Step 1: Install Flutter Dependencies

Open PowerShell, navigate to the `frontend` directory:

```powershell
cd frontend
flutter pub get
```

### Step 2: Configure Network Settings

The app automatically uses different API URLs based on the platform:

| Platform | API URL | Use Case |
|----------|---------|----------|
| Android Emulator | `http://10.0.2.2:8000` | Default for emulator |
| Physical Android Phone | `http://[YOUR_PC_IPv4]:8000` | Change baseUrl in main.dart |
| iOS/Windows | `http://localhost:8000` | Development only |

**To use a physical Android phone:**
1. Find your PC's IPv4 address: Open PowerShell and run `ipconfig`
2. Look for IPv4 Address (e.g., `192.168.x.x`)
3. Update line 118 in `main.dart`:
   ```dart
   baseUrl = Platform.isAndroid ? "http://192.168.x.x:8000" : "http://localhost:8000";
   ```

### Step 3: Run the Flutter App

#### On Android Emulator
```powershell
flutter run -d emulator-5554
```

#### On Physical Android Device
1. Connect device via USB
2. Enable USB debugging on device
3. Run:
```powershell
flutter run
```

#### Clean Build (if issues arise)
```powershell
flutter clean
flutter pub get
flutter run
```

---

## Part 3: Complete Workflow

### Full Startup Sequence

**Terminal 1 - Backend Server:**
```powershell
cd d:\projeks\internship\P2\NNT2\NeuralNT
python backend_api.py
```

**Terminal 2 - Flutter Frontend:**
```powershell
cd d:\projeks\internship\P2\NNT2\NeuralNT\frontend
flutter run
```

### Using the Application

#### 1. **Build Tab** - Design Neural Network
- Click "Add Layer" buttons to add Conv2d, Linear, ReLU, etc.
- View your architecture in real-time
- Click "Reset Architecture" to start over

#### 2. **Train Tab** - Train the Model
1. Select a ZIP file containing your dataset
   - Dataset structure: `dataset.zip/class1/images...` and `dataset.zip/class2/images...`
2. Configure training parameters:
   - **Loss Function**: CrossEntropyLoss or MSELoss
   - **Optimizer**: Adam or SGD
   - **Learning Rate**: 0.001 (recommended)
   - **Batch Size**: 32 (adjust for your hardware)
   - **Image Size**: 32 (CIFAR-10) or 224 (ImageNet)
   - **Epochs**: 10-50
3. Click **START TRAINING**
4. Monitor training logs in real-time

#### 3. **Test Tab** - Make Predictions
1. **Capture or Upload Image**:
   - Click "Gallery" to select image from device
   - Click "Camera" to capture new photo
2. Click **RUN PREDICTION**
3. View results:
   - Predicted class
   - Confidence percentage

---

## Part 4: Troubleshooting

### Backend Issues

#### Port 8000 Already in Use
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process
taskkill /PID [PID] /F
```

#### "No module named 'torch'"
```powershell
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### Frontend Issues

#### "API Unavailable" Error on Mobile
1. Ensure backend is running: `python backend_api.py`
2. Check PC's IPv4 address: `ipconfig`
3. Update baseUrl in `main.dart` if using physical device
4. Ensure firewall allows port 8000:
   ```powershell
   netsh advfirewall firewall add rule name="Allow 8000" dir=in action=allow protocol=tcp localport=8000
   ```

#### "Connection Refused"
1. Verify backend is running
2. Check if you're on the same network
3. For emulator, try: `flutter run -d emulator-5554`

#### "No Internet Connection" on Emulator
1. Ensure Android emulator has internet access
2. Restart emulator: `emulator -avd [AVD_NAME] -no-snapshot-load`

#### Permissions Denied (Images/Camera)
The app will request permissions automatically. If denied:
1. Go to Android Settings > Apps > NeuralNT
2. Grant Camera and Photo permissions
3. Restart the app

---

## Part 5: API Request Examples

### Train a Model (cURL example)

```bash
curl -X POST "http://localhost:8000/train" \
  -F "loss_name=CrossEntropyLoss" \
  -F "opt_name=Adam" \
  -F "lr=0.001" \
  -F "batch_size=32" \
  -F "image_size=32" \
  -F "epochs=10" \
  -F "num_channels=3" \
  -F "dataset=@path/to/dataset.zip"
```

### Make a Prediction (cURL example)

```bash
curl -X POST "http://localhost:8000/predict" \
  -F "image=@path/to/image.jpg" \
  -F "image_size=32"
```

---

## Part 6: Performance Tips

| Aspect | Recommendation |
|--------|-----------------|
| **Batch Size** | Use 32-64 for 8GB+ RAM; 16 for 4GB |
| **Image Size** | Smaller (32x32) trains faster; larger (224x224) more accurate |
| **Epochs** | Start with 10-20; increase for better accuracy |
| **Device** | GPU training is 10-50x faster; use CPU if no GPU available |
| **Network** | Use WiFi for mobile app; WiFi is faster than cellular |

---

## Part 7: Deployment to Production

### For Real Android Devices

1. **Build APK:**
```powershell
flutter build apk --release
```

2. **Build App Bundle (Google Play):**
```powershell
flutter build appbundle --release
```

3. **Backend Hosting** (for production):
   - Deploy backend to cloud (AWS, Google Cloud, etc.)
   - Update API URL in Flutter app
   - Use HTTPS instead of HTTP

---

## Directory Structure

```
d:\projeks\internship\P2\NNT2\NeuralNT\
├── backend_api.py              (Main API - run this)
├── app.py                       (Gradio dashboard - optional)
├── model_builder.py
├── training.py
├── validation.py
├── layers.py
├── utils.py
├── data_loader.py
├── requirements.txt
├── outputs/
│   └── trained_model.pt         (Generated after training)
└── frontend/
    ├── lib/
    │   └── main.dart            (Flutter app - edit for custom IP)
    ├── android/
    │   └── app/src/main/
    │       ├── AndroidManifest.xml
    │       └── res/xml/
    │           └── network_security_config.xml
    ├── pubspec.yaml
    └── ... (other Flutter files)
```

---

## Support & Common Issues

### Mobile Can't Connect to Backend
- **Emulator**: Use `10.0.2.2`
- **Physical phone**: Use your PC's IPv4 address (e.g., `192.168.1.100`)
- **Same network**: Ensure phone and PC are on the same WiFi

### Training is Slow
- Reduce batch size gradually (32 → 16 → 8)
- Use smaller image size (32x32 instead of 224x224)
- Use fewer epochs for testing
- Consider GPU training if available

### Model Not Found Error
- Train a model first (Train tab)
- Check `outputs/trained_model.pt` exists
- Model only persists on the PC running backend

---

## Next Steps

1. Prepare your dataset in ZIP format
2. Start the backend server
3. Launch the Flutter app
4. Build your custom neural network
5. Train on your dataset
6. Test predictions with real images

**Happy training! 🚀**
