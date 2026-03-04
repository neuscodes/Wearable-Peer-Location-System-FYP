## Peer Locating Wearable System

### Project Overview

This project is a wearable peer location system designed to help users locate a paired device using real-time location tracking and BLE. The system provides haptic and visual cues to guide the user toward the target device.

The solution consists of:

* Flutter mobile application (built for Android only)
* ESP32-based wearable hardware
* Firebase Firestore (expired — see note below)

---

## Key Features

* Software based distance estimation
* Vibration intensity feedback
* LED status indication
* Peer device pairing
* Event logging with timestamps
* Cloud synchronization

---

## Mobile Application

**Platform:** Android only
**Framework:** Flutter / Dart

## Mobile Application Functions

* Device pairing interface
* Real-time distance monitoring with paired device
* Data synchronization with Firestore
* Communication with hardware via BLE.

> **Note:** The Flutter app is currently built for Android only.

---

##  Hardware Requirements

>  **Important:** Two identical hardware units are required for the system to function properly.

Each wearable device contains:

* ESP32
* LED
* PWM Vibration Motor
* 4-pin Push Button
* 220Ω Resistor
* Jumper Wires

### Hardware Role

* Communication with mobile app via BLE
* Provides haptic feedback
* Indicates status via LED
* Handles user input via button

---

## System Architecture

Refer to the diagrams inside the **Reports/** folder for:

* Overall system architecture
* Hardware wiring diagrams
* Communication flow

---

## Firebase Status

 **Firebase Firestore has expired**

The cloud database was originally used for:

* Device logs
* Event tracking
* Remote monitoring

This repository is maintained for **academic and portfolio demonstration purposes**.

If you wish to reuse the project:

1. Create a new Firebase project
2. Replace the configuration files
3. Update the Firestore rules accordingly

---

## Project Structure

```
.
├── mobile_app/        # Flutter Android application
├── firmware/          # ESP32 Arduino firmware
├── Reports/           # Documentation, diagrams, demo video
└── README.md
```

---

## Documentation & Demo

All supporting materials are available inside the **Reports/** folder, including:

* Final report
* System diagrams
* Demo video

---

## To Setup

### Flutter App

Prerequisites:

* Flutter SDK
* Android Studio or VS Code
* Android device/emulator

Run:

```bash
flutter pub get
flutter run
```

---

### ESP32 Firmware

Prerequisites:

* Arduino IDE
* ESP32 board package installed

Steps:

1. Open the `.ino` file in Arduino IDE
2. Select ESP32 board
3. Upload to ESP32 device

---

## Important Notes:

* Firebase instance expired
* Android platform only
* Requires two hardware units
* External Environment may affect performance

---

## Author

* Cho Jing Shun Alvin
* Asia Pacific University of Technology & Innovation (APU)
* Bachelor of Science (Honours) in Information Technology 
* Major: Internet of Things (IoT)
* Final Year Project

---

## Live Demo Link (YouTube)
https://youtu.be/JDha4yUWoLA