# AttendScan 📱🤖

> **Final Year Project (FYP)**  
> **Faculty of Information and Communication Technology (FICT)**  
> **Universiti Tunku Abdul Rahman (UTAR)**

---

## 📌 Project Overview
AttendScan is an automated mobile application designed to streamline the examination attendance marking process for **University Students** and **Administrative Staff** at UTAR. 

The system provides a minimalist and intuitive mobile experience to eliminate manual paperwork, replacing it with an automated, AI-verified, and location-secure check-in workflow.

### Key Features
* **Custom AI HTR Pipeline**: Automatically extracts and parses handwritten student credentials from physical examination attendance slips using a custom-trained deep learning framework.
* **Geofencing Verification**: Restricts and validates student attendance check-ins within designated campus parameters (UTAR Kampar Campus / UTAR Sungai Long Campus).
* **Minimalist UI/UX**: Designed with a clean, user-friendly interface powered by a distinct coral orange theme.

---

## 🏗️ System Architecture & Deployment

Unlike traditional full-stack applications, this repository functions as a client-focused codebase with a decoupled cloud AI infrastructure:

* **Frontend (This Repository)**: Built entirely using the **Flutter** framework (Dart) to deliver a seamless cross-platform mobile experience.
* **Backend & AI Inference (Hosted Externally)**: The custom deep learning models and HTR inference pipelines are fully hosted and managed on **Hugging Face Spaces**. The mobile app communicates directly with the Hugging Face endpoints via HTTPS API requests.

---

## 🧠 Core AI Model & Training Details

The heart of AttendScan is a custom-built, state-of-the-art **CNN-BiLSTM-CTC Handwritten Text Recognition (HTR)** model developed to handle real-world variations in handwriting on attendance slips.

### Model Architecture & Optimization:
* **Architecture**: Combining Convolutional Neural Networks (CNN) for feature extraction, Bidirectional Long Short-Term Memory (BiLSTM) for sequence modeling, and Connectionist Temporal Classification (CTC) loss for sequence alignment.
* **Frameworks**: Developed using **TensorFlow** and **Keras**, with image preprocessing handled via **OpenCV**.
* **Hyperparameter Tuning**: Fine-tuned using **Optuna** to find the optimal architecture and training constraints.

### Dataset & Performance:
* **Training Data**: Trained on a comprehensive hybridized dataset combining the **IAM Handwriting Database**, **MNIST**, and a curated **custom dataset of real UTAR examination attendance slips** with specialized data augmentation techniques.
* **Evaluation Metrics**: Achieved a remarkable **92.83% character-level accuracy** (resulting in a low Character Error Rate of **7.17% CER**) when evaluated against real UTAR exam slips, ensuring highly reliable student credential validation.
