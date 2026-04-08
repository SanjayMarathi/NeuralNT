# 🧠 NeuralNT

NeuralNT is a high-performance cross-platform system that separates machine learning configuration from hardware execution. It enables users to build, train, configure, and monitor deep neural networks directly from a mobile device while offloading heavy computation to a cloud-based GPU backend.

---

## 🚀 Features

* **Cloud GPU Training via Mobile**
  Train neural networks without requiring local GPUs. All computations run on remote environments like Hugging Face Spaces.

* **Asynchronous Mobile UI**
  Smooth navigation using `IndexedStack`, allowing background training while switching between screens.

* **Live Training Monitoring**
  Real-time logs, timers, and training progress streamed via SSE.

* **Model Storage & History**
  Stores prediction results and trained models locally using `shared_preferences` for quick access.

---

## 🏗 Architecture

The project consists of three main components:

### 📱 neuralnt_mobile/ (Flutter App)

* Built with Flutter (Dart)
* Provides UI for training, prediction, and monitoring
* Supports dark/light mode and real-time updates

**Build:**

```bash
cd neuralnt_mobile
flutter clean
flutter pub get
flutter build apk --release
```

---

### ☁️ training_service/ (Backend API)

* Built with Python, FastAPI, and PyTorch
* Handles model training and inference
* Streams logs and returns trained models as Base64

**Run Locally:**

```bash
cd training_service
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 7860 --reload
```

**Deployment:**
Deploy using Docker on Hugging Face Spaces.

---

### 💻 web_client/ (Testing Interface)

* Built using Gradio
* Used for testing training configurations via browser

**Run:**

```bash
cd web_client
python app.py
```

---

## 🔄 Workflow

1. Deploy backend (`training_service`) on cloud
2. Backend exposes APIs: `/health`, `/train`, `/predict`
3. Mobile app connects to backend
4. User uploads dataset and config via mobile
5. Model is trained on GPU and logs are streamed
6. Output model is returned and stored locally

---

## ⚙️ Prerequisites

* Flutter SDK (v3.19+)
* Python 3.11+
* pip
* Docker (optional)
* Hugging Face account

---

## 🏁 Quickstart

### Start Backend

```bash
cd training_service
pip install -r requirements.txt
uvicorn app:app --reload
```

### Run Mobile App

```bash
cd neuralnt_mobile
flutter pub get
flutter run
```

---

## 📌 Advantages

* No need for high-end hardware
* Fully mobile-based ML workflow
* Scalable cloud architecture
* Real-time monitoring
* Easy deployment

---

## 📄 Conclusion

NeuralNT simplifies deep learning by combining mobile accessibility with cloud computing. It allows users to train and manage neural networks efficiently without requiring powerful local systems.
