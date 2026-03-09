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

**Platform:** Android only\
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
├── Reports/           # Diagrams, demo video
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

## Live Demo Link (YouTube)
https://youtu.be/JDha4yUWoLA

---

## Disclaimer
This project was developed as part of a Final Year Project (FYP). The repository is published as a portfolio demonstration of the system design and implementation conducted during the project.

The software and hardware implementations are provided as-is without any guarantees for real-world deployment. The system was tested within the scope of the academic project, and is not evaluated for production or commercial use.

Any usage of the code or design from this repository is done at the **user's own risk.**

The thesis document remains the property of the university, and this repository only contains selected project materials for **educational and demonstration purposes only.**

---

## Author/Credits

Cho Jing Shun Alvin\
Fresh Graduate\
Asia Pacific University of Technology & Innovation (APU)\
Bachelor of Science (Honours) in Information Technology\
Major: Internet of Things (IoT)

---