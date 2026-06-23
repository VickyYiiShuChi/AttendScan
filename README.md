# AttendScan 📱🤖

> **Final Year Project (FYP)** > **Faculty of Information and Communication Technology (FICT)** > **Universiti Tunku Abdul Rahman (UTAR)**

---

## 📌 Project Overview
AttendScan is an automated multi-platform system designed to streamline the examination attendance marking process for **University Students** and **Administrative Staff** at UTAR. 

The system provides a minimalist and intuitive mobile experience to eliminate manual paperwork for students, combined with a comprehensive centralized web dashboard for administrators to monitor, manage, and verify student records and attendance logs in real time.

### Key Features
* **Custom AI HTR Pipeline**: Automatically extracts and parses handwritten student credentials from physical examination attendance slips using a custom-trained deep learning framework.
* **Geofencing Verification**: Restricts and validates student attendance check-ins within designated campus parameters (UTAR Kampar Campus / UTAR Sungai Long Campus).
* **Centralized Admin Management**: Provides a web-based dashboard for administrative staff to manage exam schedules, view student profiles, and export attendance records.
* **Minimalist UI/UX**: Designed with a clean, user-friendly interface powered by a distinct coral orange theme.

---

## 🏗️ System Architecture & Deployment

The repository functions as a client-focused codebase with a decoupled cloud AI infrastructure, split into the following operational components:

* **Frontend Mobile Client (This Repository)**: Built entirely using the **Flutter** framework (Dart) to deliver a seamless cross-platform mobile experience for students to perform scanning and geofenced check-ins.
* **Admin Web Dashboard**: A web-based interface tailored for administrative staff to manage examination schedules, student lists, and overall attendance records.
* **Backend & AI Inference (Hosted Externally)**: The custom deep learning models and HTR inference pipelines are fully hosted and managed on **Hugging Face Spaces**. Both the mobile client and the admin website communicate directly with the cloud backend via secure HTTPS API requests.

---

## 🧠 Core AI Model & Training Details

The heart of AttendScan is a custom-built, state-of-the-art **CNN-BiLSTM-CTC Handwritten Text Recognition (HTR)** model developed to handle real-world variations in handwriting on attendance slips.

### Model Architecture & Optimization
* **Architecture**: Combining Convolutional Neural Networks (CNN) for feature extraction, Bidirectional Long Short-Term Memory (BiLSTM) for sequence modeling, and Connectionist Temporal Classification (CTC) loss for sequence alignment.
* **Frameworks**: Developed using **TensorFlow** and **Keras**, with image preprocessing handled via **OpenCV**.
* **Hyperparameter Tuning**: Fine-tuned using **Optuna** to find the optimal architecture and training constraints.

### Dataset & Performance
* **Training Data**: Trained on a comprehensive hybridized dataset combining the **IAM Handwriting Database**, **MNIST**, and a curated **custom dataset of real UTAR examination attendance slips** with specialized data augmentation techniques.
* **Evaluation Metrics**: Achieved a remarkable **92.83% character-level accuracy** (resulting in a low Character Error Rate of **7.17% CER**) when evaluated against real UTAR exam slips, ensuring highly reliable student credential validation.

---

## 🚀 Getting Started (Local Development)

To run the application locally, you **only need to set up the Flutter client**. The application is pre-configured to automatically route HTR requests to the cloud-hosted Hugging Face inference service.

### 1. Clone the Repository
```bash
git clone [https://github.com/VickyYiiShuChi/AttendScan.git](https://github.com/VickyYiiShuChi/AttendScan.git)
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

* **Frontend Mobile Client**: Flutter, Dart
* **Admin Web Portal**: Flutter Web, Hosted on Firebase Hosting
* **Cloud AI Infrastructure**: Python, TensorFlow, Keras, OpenCV, Optuna
* **AI Hosting Space**: [Hugging Face Spaces (vky-04/exam-attendance-app-api)](https://huggingface.co/spaces/vky-04/exam-attendance-app-api)

