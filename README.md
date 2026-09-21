# AttendScan 📱🤖

> **Final Year Project (FYP)**
> **Faculty of Information and Communication Technology (FICT)**
> **Universiti Tunku Abdul Rahman (UTAR)**

---

## 📌 Project Overview

AttendScan is an automated multi-platform system designed to streamline the examination attendance marking process for **university students** and **administrative staff** at UTAR.

The system provides a minimalist and intuitive mobile experience to reduce manual paperwork for students, combined with a centralized web dashboard for administrators to monitor, manage, and verify student records and attendance logs in real time.

### Key Features

* **Custom AI HTR Pipeline**: Automatically extracts and parses handwritten student credentials from physical examination attendance slips using a custom-trained deep learning framework.
* **Geofencing Verification**: Restricts and validates student attendance check-ins within designated campus parameters (UTAR Kampar Campus / UTAR Sungai Long Campus).
* **Centralized Admin Management**: Provides a web-based dashboard for administrative staff to manage exam schedules, view student profiles, and export attendance records.
* **Firebase Integration**: Uses Firebase services for authentication, cloud database management, storage, and web hosting.
* **Local Data Persistence**: Uses SharedPreferences for lightweight local storage and application preferences.
* **Minimalist UI/UX**: Designed with a clean, user-friendly interface powered by a distinct coral orange theme.

---

## 🏗️ System Architecture

AttendScan follows a layered architecture consisting of the **User Layer, API Layer, Model Layer, and Data Layer**, supported by cloud-based deployment infrastructure.

<p align="center">
  <img src="diagram/System%20Architecture%20Diagram.png" width="850">
</p>

### System Components

#### 👤 User Layer

* **Student Mobile Application**: Built with **Flutter (Dart)** for students to scan examination attendance slips, perform geofenced attendance check-ins, and access examination information.
* **Admin Web Dashboard**: Provides administrative staff with a web-based interface to manage examination schedules, student records, and attendance data.

#### 🌐 API Layer

* **FastAPI Backend**: Provides REST API endpoints for communication between the client applications and the AI inference service.
* **REST API Communication**: Transfers attendance slip images and related requests through secure HTTPS API requests and returns handwriting recognition results to the client application.

#### 🧠 Model Layer

* **CNN-BiLSTM-CTC HTR Model**: Performs handwritten text recognition by combining CNN-based visual feature extraction, BiLSTM sequence modeling, and CTC for sequence alignment and text recognition.
* **AI Inference Service**: The trained model and HTR inference pipeline are deployed on **Hugging Face Spaces** for cloud-based inference.

#### 🗄️ Data Layer

* **Cloud Firestore**: Stores examination schedules, student information, and attendance records.
* **Firebase Authentication**: Handles user authentication and access control.
* **Firebase Storage**: Stores application-related files and uploaded data.
* **SharedPreferences**: Provides lightweight local storage for selected user preferences and application settings.

#### ☁️ Deployment Infrastructure

* **Firebase Hosting**: Hosts and deploys the administrative web application.
* **Hugging Face Spaces**: Hosts the AI model and inference service.

---

## 🧠 AI Model & Training

The core AI component of AttendScan is a custom **CNN-BiLSTM-CTC Handwritten Text Recognition (HTR)** model developed to recognize handwritten information from examination attendance slips.

### Model Architecture

<p align="center">
  <img src="diagram/CNN-BiLSTM-CTC%20Model%20Architecture%20Diagram.png" width="850">
</p>

The model consists of three main components:

* **CNN (Convolutional Neural Network)**: Extracts visual features from handwritten input images.
* **BiLSTM (Bidirectional Long Short-Term Memory)**: Captures sequential information from the extracted visual features.
* **CTC (Connectionist Temporal Classification)**: Performs sequence alignment and enables text recognition without requiring character-level segmentation.

### Model Development & Optimization

* **Frameworks**: Developed using **TensorFlow** and **Keras**, with image preprocessing handled using **OpenCV**.
* **Hyperparameter Tuning**: Fine-tuned using **Optuna** to identify suitable model architecture and training parameters.
* **Data Augmentation**: Applied augmentation techniques to improve the model's ability to handle variations in real-world handwriting.

### Dataset & Performance

* **Training Data**: Trained on a hybrid dataset combining the **IAM Handwriting Database**, **MNIST**, and a curated **custom dataset of real UTAR examination attendance slips**.
* **Evaluation Metrics**: Achieved **92.83% character-level accuracy**, corresponding to a **7.17% Character Error Rate (CER)** when evaluated against real UTAR examination slips.

---

## 📱 Application Features

### Student Mobile Application

The Flutter mobile application provides students with:

* Examination attendance slip scanning
* AI-powered handwritten information recognition
* Geofenced attendance verification
* Examination and attendance information
* User authentication
* Local application preferences

### Admin Web Dashboard

The web dashboard provides administrative staff with:

* Examination schedule management
* Student record management
* Attendance record monitoring
* Attendance verification
* Attendance data export

---

## 🚀 Getting Started

To run the application locally, you **only need to set up the Flutter client**. The application is pre-configured to route HTR requests to the cloud-hosted Hugging Face inference service.

### 1. Clone the Repository

```bash
git clone https://github.com/VickyYiiShuChi/AttendScan.git
cd AttendScan
```

### 2. Run the Mobile App (Android)

```bash
flutter pub get
flutter run
```

### 3. Run the Admin Web Portal (Web)

```bash
flutter pub get
flutter run -d chrome
```

---

## 🛠️ Tech Stack & Cloud Infrastructure

### Frontend & Application

* **Flutter**
* **Dart**
* **Flutter Web**
* **SharedPreferences**

### Backend & API

* **FastAPI**
* **REST API**
* **HTTPS**

### Database & Cloud Services

* **Firebase Authentication**
* **Cloud Firestore**
* **Firebase Storage**
* **Firebase Hosting**
* **Hugging Face Spaces**

### AI & Machine Learning

* **Python**
* **TensorFlow**
* **Keras**
* **OpenCV**
* **Optuna**
* **CNN-BiLSTM-CTC**

### AI Hosting

* [Hugging Face Spaces - Exam Attendance App API](https://huggingface.co/spaces/vky-04/exam-attendance-app-api)
