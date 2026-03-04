#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ================= PINS =================
#define LED_R_PIN 5
#define LED_G_PIN 18
#define LED_B_PIN 19
#define VIB_PIN   22
#define BTN_PIN   23

// ================= BLE UUIDS =================
#define SERVICE_UUID        "6E416761-1A98-4F47-9B7A-8F6B2CCF0001"
#define CHARACTERISTIC_TX  "6E416762-1A98-4F47-9B7A-8F6B2CCF0002"
#define CHARACTERISTIC_RX  "6E416763-1A98-4F47-9B7A-8F6B2CCF0003"

// ================= GLOBALS =================
BLECharacteristic *txChar;
BLECharacteristic *rxChar;
BLEAdvertising* advertising = nullptr;
bool deviceConnected = false;
unsigned long lastActivity = 0;
unsigned long lastButtonPress = 0;
unsigned long lastVibTime = 0;
unsigned long stateTimestamp = 0;
bool lastButtonState = HIGH;
bool buttonPressed = false;

String deviceID = "DEV-" + String((uint32_t)ESP.getEfuseMac(), HEX);

enum DeviceState {    // State of the wearable device
  STATE_BOOT,
  STATE_IDLE,
  STATE_PAIRING,
  STATE_CONNECTED,
  STATE_TRACKING,
  STATE_ALERT,
  STATE_DISCONNECTED,
  STATE_SLEEP_DISCONNECTED,
  STATE_SLEEP_CONNECTED
};

enum ProximityZone {    // Used for determining distance
  ZONE_NONE,
  ZONE_FAR,
  ZONE_MID,
  ZONE_NEAR,
  ZONE_FOUND
};

ProximityZone currentZone = ZONE_NONE;

DeviceState currentState;
// DeviceState currentState = STATE_BOOT;

// ================= Haptic Feedback =================
void handleHaptics() {
  if (currentState != STATE_TRACKING) return;
  static unsigned long lastBuzz = 0;
  unsigned long now = millis();

  int interval = 0;

  if (currentZone == ZONE_NONE) {
    vibOff();
    return;
  }

  switch (currentZone) {
    case ZONE_FAR:
      interval = 1200; // slow buzz
      break;

    case ZONE_MID:
      interval = 600;
      break;

    case ZONE_NEAR:
      interval = 200; // rapid buzz
      break;

    default:
      return;
  }

  if (now - lastBuzz >= interval) {
    vibPulse(200);
    lastBuzz = now;
  }
}

// ================= LED CONTROL =================
void ledOff() {
  digitalWrite(LED_R_PIN, LOW);
  digitalWrite(LED_G_PIN, LOW);
  digitalWrite(LED_B_PIN, LOW);
}

void ledBlue() {
  digitalWrite(LED_R_PIN, LOW);
  digitalWrite(LED_G_PIN, LOW);
  digitalWrite(LED_B_PIN, HIGH);
}

void ledGreen() {
  digitalWrite(LED_R_PIN, LOW);
  digitalWrite(LED_G_PIN, HIGH);
  digitalWrite(LED_B_PIN, LOW);
}

void ledRed() {
  digitalWrite(LED_R_PIN, HIGH);
  digitalWrite(LED_G_PIN, LOW);
  digitalWrite(LED_B_PIN, LOW);
}

void ledBlueFlash3() {
  for (int i = 0; i < 3; i++) {
    ledBlue();
    delay(200);
    ledOff();
    delay(200);
  }
}

// ================= VIBRATION CONTROL =================
void vibOn() {
  digitalWrite(VIB_PIN, HIGH);
}

void vibOff() {
  digitalWrite(VIB_PIN, LOW);
}

void vibPulse(int ms) {
  vibOn();
  delay(ms);
  vibOff();
}

// ================= BUTTON CONTROL =================
void updateButton() {
  bool current = digitalRead(BTN_PIN);
  buttonPressed = (lastButtonState == HIGH && current == LOW);
  lastButtonState = current;
}

void handleTrackingButton() {       // For tracking start only. 
  if (currentState != STATE_CONNECTED) return;
  static unsigned long pressStart = 0;

  if (digitalRead(BTN_PIN) == LOW) {
    if (pressStart == 0) pressStart = millis();

    if (millis() - pressStart >= 2000) {
      vibOff();
      changeState(STATE_TRACKING);
      pressStart = 0;
    }
  } else {
    pressStart = 0;
  }
}


// ================= State Changes =================
void changeState(DeviceState newState) {
  if (currentState == newState) return;
  Serial.printf("STATE: %d > %d\n", currentState, newState);

  vibOff();
  currentState = newState;
  stateTimestamp = millis();

  switch (newState){
    case STATE_CONNECTED:
      vibPulse(120);
      handleNotify("STATE:CONNECTED\n");
    break;

    case STATE_TRACKING:
      handleNotify("STATE:TRACKING\n");
    break;

    case STATE_ALERT:
      handleNotify("STATE:ALERT\n");
    break;

    case STATE_DISCONNECTED:
      handleNotify("STATE:DISCONNECTED\n");
    break;
  }
}

void handleNotify(String cmd) {   // Sends notification to phone.
  if (txChar == nullptr) return;
  if (deviceConnected) {
    txChar->setValue(cmd.c_str());
    txChar->notify();
    
    Serial.println("handleNotify: " + cmd);
  }
}

// ================= BLE CALLBACKS =================
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) {
    deviceConnected = true;
    changeState(STATE_CONNECTED);
    ledBlueFlash3();
    vibPulse(200);
  }

  void onDisconnect(BLEServer*) {
    deviceConnected = false;
    changeState(STATE_DISCONNECTED);
  }
};

class RXCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) {
    if (!deviceConnected) return;
    String msg = characteristic->getValue().c_str();
    msg.trim();
    lastActivity = millis();

    Serial.println("RX: " + msg);

    handleCommand(msg);
  }
};

// Responsible for all command handling.
void handleCommand(String cmd) {
  cmd.trim();

   // -------- App asks current state --------
  if (cmd == "STATE?") {
    switch (currentState){
      case STATE_BOOT:
        handleNotify("STATE:BOOT\n");
      break;

      case STATE_IDLE:
        handleNotify("STATE:IDLE\n");
      break;

      case STATE_PAIRING:
        handleNotify("STATE:PAIRING\n");
      break;

      case STATE_CONNECTED:
        handleNotify("STATE:CONNECTED\n");
      break;

      case STATE_TRACKING:
        handleNotify("STATE:TRACKING\n");
      break;

      case STATE_ALERT:
        handleNotify("STATE:ALERT\n");
      break;

      case STATE_DISCONNECTED:
        handleNotify("STATE:DISCONNECTED\n");
      break;

      case STATE_SLEEP_CONNECTED:
        handleNotify("STATE:SLEEP_CONNECTED\n");
      break;

      case STATE_SLEEP_DISCONNECTED:
        handleNotify("STATE:SLEEP_DISCONNECTED\n");
      break;
    }
    return;
  }

  // -------- Start tracking --------
  if (cmd == "TRACK:START") {
    if (currentState == STATE_CONNECTED) {
      currentZone = ZONE_NONE;
      changeState(STATE_TRACKING);
      ledGreen();
      handleNotify("ACK:TRACK\n");
    }
    return;
  }

  // -------- Stop tracking --------
  if (cmd == "TRACK:STOP") {
    if (currentState == STATE_TRACKING) {
      vibOff();
      ledOff();
      changeState(STATE_CONNECTED);
      handleNotify("ACK:STOP\n");
    }
    return;
  }

  // -------- Distance updates from app --------
  if (cmd.startsWith("DIST:")) {
    if (currentState != STATE_TRACKING) return;
    handleNotify("ACK:DIST\n");

    if (cmd.endsWith("FAR")) {
      currentZone = ZONE_FAR;
      handleNotify("ACK:ZONE:FAR\n");
    } 
    else if (cmd.endsWith("MID")) {
      currentZone = ZONE_MID;
      handleNotify("ACK:ZONE:MID\n");
    } 
    else if (cmd.endsWith("NEAR")) {
      currentZone = ZONE_NEAR;
      handleNotify("ACK:ZONE:NEAR\n");
    } 
    else if (cmd.endsWith("FOUND")) {
      currentZone = ZONE_FOUND;
      changeState(STATE_ALERT);
      handleNotify("ACK:ZONE:FOUND\n");
      // vibOn();
    }
    return;
  }

  // -------- Pairing control --------    // May or may not need.
  if (cmd == "PAIR") {
    changeState(STATE_PAIRING);
    return;
  }

  if (cmd == "UNPAIR") {
    changeState(STATE_IDLE);
    return;
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  pinMode(LED_R_PIN, OUTPUT);
  pinMode(LED_G_PIN, OUTPUT);
  pinMode(LED_B_PIN, OUTPUT);
  pinMode(VIB_PIN, OUTPUT);
  pinMode(BTN_PIN, INPUT_PULLUP);

  ledBlue();

  BLEDevice::init(deviceID.c_str());
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  // ESP32 > Phone
  txChar = service->createCharacteristic(
    CHARACTERISTIC_TX,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
  );
  txChar->addDescriptor(new BLE2902());

  // Phone > ESP32 
  rxChar = service->createCharacteristic(
    CHARACTERISTIC_RX,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  rxChar->setCallbacks(new RXCallbacks());

  service->start();

  currentState = STATE_BOOT;
  advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);

  Serial.println("BLE Ready, DeviceID: " + deviceID);
}

// ================= LOOP =================
void loop() {
  updateButton();
  switch (currentState) {

    case STATE_BOOT:
      changeState(STATE_IDLE);
      break;

    case STATE_IDLE:
      // No LED and vibrations.
      // Wait for pairing, hold button for 3 seconds to start pairing (STATE_PAIRING). Goes sleep mode (STATE_SLEEP_DISCONNECTED) if no activity for 15 seconds.
      ledOff();
      if (buttonPressed) {
        lastActivity = millis();
        changeState(STATE_PAIRING);
      }

      // Auto sleep after inactivity
      if (millis() - lastActivity > 15000) {
        changeState(STATE_SLEEP_DISCONNECTED);
      }
      break;

    case STATE_PAIRING: {
      // Light LED Blue during pairing. Start advertising BLE.
      ledBlue();
      if (advertising) {
        advertising->start();
      }

      if (millis() - stateTimestamp >= 30000) {  // Pairing timeout 30s
        if (advertising) advertising->stop();
        changeState(STATE_IDLE);
      }
      break;
    }
    case STATE_CONNECTED:
      // When button hold for 2 seconds, starts to track the other device (STATE_TRACKING);
      // If no action for 30 seconds, goes to "SLEEP" (STATE_SLEEP_CONNECTED) mode.
      
      ledOff();
      handleTrackingButton();       // Check if button hold for 2 seconds

      // Sleep if idle
      if (millis() - lastActivity > 30000) {
        changeState(STATE_SLEEP_CONNECTED);
      }
      break;

    case STATE_TRACKING:
      // Light LED Green, notifies the app start locating the user.
      // Press button to turn off tracking.
      
      ledGreen();
      handleHaptics();  // Based on the distance response from BLE, provide different haptic feedbacks.
      static bool btnReleased = false;

      if (digitalRead(BTN_PIN) == HIGH) {
        btnReleased = true;
      }

      if (btnReleased && digitalRead(BTN_PIN) == LOW) {
        btnReleased = false;
        changeState(STATE_CONNECTED);
      }
      break;

    case STATE_ALERT:  // Happen when device found.
      
      vibOn();
      if (millis() - stateTimestamp >= 5000) {
        vibOff();
        changeState(STATE_CONNECTED);
      }
      break;

    case STATE_DISCONNECTED:
      // Light LED Red until auto pair.
      vibOff();
      ledRed();
      if (millis() - stateTimestamp >= 5000) {  // Tries to auto pair after 5 secs
        changeState(STATE_PAIRING);
      }
      break;

    case STATE_SLEEP_CONNECTED:
      // Listen any actions (button presses, BLE msg etc.), goes back to connected state (STATE_CONNECTED).
      // Ensure as little power usage as possible. MUST preserve BLE connection.
      ledOff();
      if (buttonPressed) {
        lastActivity = millis();
        changeState(STATE_CONNECTED);
      }

      if (millis() - lastActivity < 500) {
        changeState(STATE_CONNECTED);
      }

      if (!deviceConnected) {
        changeState(STATE_DISCONNECTED);
      }
      break;

    case STATE_SLEEP_DISCONNECTED:
      // Listens for button press. When button press, go back to IDLE (STATE_IDLE).
      // Ensure minimal power usage.
      // Need to change pin layout to 
      ledOff();
      vibOff();

      if (buttonPressed) {
        lastActivity = millis();
        changeState(STATE_IDLE);
      }
      break;
  }

  delay(10);
}

