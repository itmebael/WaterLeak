/*
 * ESP32 Water Connection Control with Leak Detection
 * Integrated with Supabase for remote monitoring and control
 * 
 * Hardware:
 * - ESP32 Development Board
 * - Flow Sensor (YF-S201) on GPIO 27
 * - Relay Module on GPIO 26 (controls valve)
 * - Buzzer on GPIO 25
 * - LCD I2C (16x2) on default I2C pins (SDA=21, SCL=22)
 * 
 * Features:
 * - Flow-based leak detection
 * - Automatic valve control
 * - Real-time data to Supabase
 * - LCD status display
 * - Remote valve control via Supabase
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ================= CONFIGURATION =================
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase Configuration
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";
const char* waterControlTable = "water_connection_control";
const char* commandsTable = "water_connection_commands";
const char* sensorReadingsTable = "sensor_readings";
const char* leakDetectionsTable = "water_leak_detections";

// Device Configuration (Kitchen)
const char* deviceId = "ESP_KITCHEN_001";
const char* deviceName = "Kitchen Water Line";
const char* location = "Kitchen";
const char* segmentId = "YOUR_SEGMENT_ID";  // Get from database (kitchen segment)
const char* propertyId = "YOUR_PROPERTY_ID"; // Get from database

// ================= PINS =================
#define FLOW_SENSOR_PIN 27
#define BUZZER_PIN      25
#define VALVE_PIN       26

// ================= LCD =================
LiquidCrystal_I2C lcd(0x27, 16, 2); // Change I2C address if needed

// ================= FLOW VARIABLES =================
volatile unsigned long pulseCount = 0;
unsigned long lastTime = 0;

float flowRate = 0.0;       // L/min
float totalUsed = 0.0;      // Liters

// YF-S201 calibration (adjust based on your sensor)
const float calibrationFactor = 7.5; // Pulses per liter per minute

// ================= THRESHOLDS =================
const float leakThreshold = 0.2;   // L/min - leak detected below this
const float startThreshold = 2.0;  // L/min - normal flow above this

// ================= SYSTEM STATE =================
bool valveOpen = false;           // Current valve state
bool leakDetected = false;
bool autoControlEnabled = true;   // Auto valve control based on flow
unsigned long lastSupabaseUpdate = 0;
unsigned long lastCommandCheck = 0;
unsigned long leakStartTime = 0;

// Timing intervals
const unsigned long SUPABASE_UPDATE_INTERVAL = 5000;  // 5 seconds
const unsigned long COMMAND_CHECK_INTERVAL = 3000;    // 3 seconds
const unsigned long LEAK_ALERT_DURATION = 10000;       // 10 seconds

// WiFi and HTTP
WiFiClientSecure client;
HTTPClient http;

// ================= ISR =================
void IRAM_ATTR pulseCounter() {
  pulseCount++;
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n=== ESP32 Kitchen Water Control System ===");
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  Serial.println("Location: Kitchen");

  // Initialize pins
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(VALVE_PIN, OUTPUT);

  // Valve default CLOSED (HIGH = closed, LOW = open)
  digitalWrite(VALVE_PIN, HIGH);
  valveOpen = false;
  digitalWrite(BUZZER_PIN, LOW);

  // Attach interrupt for flow sensor
  attachInterrupt(
    digitalPinToInterrupt(FLOW_SENSOR_PIN),
    pulseCounter,
    RISING
  );

  // Initialize LCD
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Kitchen Water");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");
  delay(1500);

  // Connect to WiFi
  connectToWiFi();

  // Initialize Supabase connection
  client.setInsecure(); // For HTTPS (use proper cert in production)

  // Register device in Supabase
  registerDevice();

  lastTime = millis();
  lastSupabaseUpdate = millis();
  lastCommandCheck = millis();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Kitchen Ready");
  lcd.setCursor(0, 1);
  lcd.print("Monitoring...");

  Serial.println("Setup complete!");
  Serial.println("System ready...\n");
}

// ================= MAIN LOOP =================
void loop() {
  unsigned long currentMillis = millis();

  // Calculate flow rate every second
  if (currentMillis - lastTime >= 1000) {
    calculateFlowRate();
    lastTime = currentMillis;

    // Update LCD display
    updateLCD();

    // Leak detection and valve control
    detectLeakAndControlValve();

    // Serial debug
    Serial.print("Flow: ");
    Serial.print(flowRate, 2);
    Serial.print(" L/min | Total: ");
    Serial.print(totalUsed, 2);
    Serial.print(" L | Valve: ");
    Serial.println(valveOpen ? "OPEN" : "CLOSED");
  }

  // Check for remote commands from Supabase
  if (currentMillis - lastCommandCheck >= COMMAND_CHECK_INTERVAL) {
    checkForCommands();
    lastCommandCheck = currentMillis;
  }

  // Update Supabase with sensor data
  if (currentMillis - lastSupabaseUpdate >= SUPABASE_UPDATE_INTERVAL) {
    sendSensorReading();
    updateDeviceStatus();
    lastSupabaseUpdate = currentMillis;
  }

  delay(100);
}

// ================= FLOW CALCULATION =================
void calculateFlowRate() {
  noInterrupts();
  unsigned long pulses = pulseCount;
  pulseCount = 0;
  interrupts();

  // Calculate flow rate: pulses per minute / calibration factor
  flowRate = (pulses * 60.0) / calibrationFactor; // L/min
  totalUsed += flowRate / 60.0; // Add liters per second
}

// ================= LEAK DETECTION & VALVE CONTROL =================
void detectLeakAndControlValve() {
  if (!autoControlEnabled) return;

  bool newLeakDetected = false;

  // Leak detection: flow between leakThreshold and startThreshold
  if (flowRate > leakThreshold && flowRate < startThreshold) {
    if (!leakDetected) {
      leakDetected = true;
      leakStartTime = millis();
      newLeakDetected = true;
      Serial.println("🚨 LEAK DETECTED!");
      
      // Report leak to Supabase
      reportLeakToSupabase();
    }
    
    // Close valve and sound alarm
    closeValve();
    // Buzzer beep (ESP32 doesn't have tone(), use digitalWrite)
    static unsigned long lastBeep = 0;
    if (millis() - lastBeep >= 500) {
      digitalWrite(BUZZER_PIN, !digitalRead(BUZZER_PIN));
      lastBeep = millis();
    }
  }
  // Normal flow: above startThreshold
  else if (flowRate >= startThreshold) {
    if (leakDetected) {
      leakDetected = false;
      Serial.println("✅ Leak resolved - Normal flow");
    }
    openValve();
    digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer
  }
  // No flow: below leakThreshold
  else {
    if (leakDetected) {
      // Check if leak has been resolved (no flow for 10 seconds)
      if (millis() - leakStartTime > LEAK_ALERT_DURATION) {
        leakDetected = false;
        Serial.println("✅ Leak resolved - No flow");
      }
    }
    closeValve();
    digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer
  }
}

// ================= VALVE CONTROL =================
void openValve() {
  if (!valveOpen) {
    digitalWrite(VALVE_PIN, LOW); // LOW = open
    valveOpen = true;
    Serial.println("Valve OPENED");
  }
}

void closeValve() {
  if (valveOpen) {
    digitalWrite(VALVE_PIN, HIGH); // HIGH = closed
    valveOpen = false;
    Serial.println("Valve CLOSED");
  }
}

// ================= LCD DISPLAY =================
void updateLCD() {
  lcd.clear();
  
  if (leakDetected) {
    // Kitchen leak alert display
    lcd.setCursor(0, 0);
    lcd.print("KITCHEN LEAK!");
    lcd.setCursor(0, 1);
    lcd.print("Flow: ");
    lcd.print(flowRate, 2);
    lcd.print(" L/m");
  } else {
    // Normal kitchen display
    lcd.setCursor(0, 0);
    lcd.print("Kitchen: ");
    lcd.print(flowRate, 2);
    lcd.print("L/m");
    
    lcd.setCursor(0, 1);
    lcd.print("Total: ");
    lcd.print(totalUsed, 1);
    lcd.print("L ");
    lcd.print(valveOpen ? "OPEN" : "CLOSED");
  }
}

// ================= WIFI CONNECTION =================
void connectToWiFi() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("RSSI: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\nWiFi connection failed!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Restarting...");
    delay(5000);
    ESP.restart();
  }
}

// ================= SUPABASE FUNCTIONS =================
void registerDevice() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(waterControlTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(1024);
  doc["device_id"] = deviceId;
  doc["device_name"] = deviceName;
  doc["location"] = location;
  doc["valve_status"] = valveOpen ? "open" : "closed";
  doc["water_flow"] = flowRate;
  doc["is_online"] = true;
  doc["last_heartbeat"] = "now()";

  String jsonString;
  serializeJson(doc, jsonString);

  int httpCode = http.POST(jsonString);

  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Device registered in Supabase");
  } else if (httpCode == 409) {
    Serial.println("Device already exists, will update...");
  } else {
    Serial.print("Registration failed. HTTP code: ");
    Serial.println(httpCode);
  }

  http.end();
}

void updateDeviceStatus() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(waterControlTable) + 
               "?device_id=eq." + String(deviceId);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(512);
  doc["valve_status"] = valveOpen ? "open" : "closed";
  doc["water_flow"] = flowRate;
  doc["is_online"] = true;
  doc["last_heartbeat"] = "now()";

  String jsonString;
  serializeJson(doc, jsonString);

  int httpCode = http.PATCH(jsonString);
  http.end();
}

void sendSensorReading() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(sensorReadingsTable);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(512);
  doc["segment_id"] = segmentId;
  doc["reading_timestamp"] = "now()";
  doc["flow_rate_lpm"] = flowRate;
  doc["sensor_status"] = leakDetected ? "warning" : "normal";

  String jsonString;
  serializeJson(doc, jsonString);

  http.POST(jsonString);
  http.end();
}

void checkForCommands() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(commandsTable) +
               "?device_id=eq." + String(deviceId) +
               "&status=eq.pending" +
               "&order=created_at.asc" +
               "&limit=1";

  http.begin(client, url);
  http.addHeader("apikey", supabaseKey);

  int httpCode = http.GET();

  if (httpCode == 200) {
    String payload = http.getString();

    if (payload.length() > 2 && payload != "[]") {
      DynamicJsonDocument doc(1024);
      deserializeJson(doc, payload);

      if (doc.is<JsonArray>() && doc.size() > 0) {
        JsonObject command = doc[0];
        String commandId = command["id"].as<String>();
        String commandType = command["command_type"].as<String>();

        Serial.print("Received command: ");
        Serial.println(commandType);

        bool success = executeCommand(commandType);

        // Update command status
        updateCommandStatus(commandId, success);
      }
    }
  }

  http.end();
}

bool executeCommand(String commandType) {
  bool success = false;

  if (commandType == "open_valve") {
    autoControlEnabled = false; // Disable auto control when manually controlled
    openValve();
    success = true;
    Serial.println("Valve opened via command");
  } else if (commandType == "close_valve") {
    autoControlEnabled = false;
    closeValve();
    success = true;
    Serial.println("Valve closed via command");
  } else if (commandType == "enable_auto") {
    autoControlEnabled = true;
    success = true;
    Serial.println("Auto control enabled");
  } else if (commandType == "get_status") {
    updateDeviceStatus();
    success = true;
  }

  return success;
}

void updateCommandStatus(String commandId, bool success) {
  String url = String(supabaseUrl) + "/rest/v1/" + String(commandsTable) + 
               "?id=eq." + commandId;

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(256);
  doc["status"] = success ? "executed" : "failed";
  doc["executed_at"] = "now()";

  String jsonString;
  serializeJson(doc, jsonString);

  http.PATCH(jsonString);
  http.end();
}

void reportLeakToSupabase() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(leakDetectionsTable);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(1024);
  doc["property_id"] = propertyId;
  doc["segment_id"] = segmentId;
  doc["detection_date"] = "now()";
  doc["leak_type"] = "drip";
  doc["severity"] = "low";
  doc["status"] = "active";
  doc["location_description"] = "Kitchen";
  doc["estimated_water_loss_rate"] = flowRate * 60; // L/hour
  doc["flow_rate_anomaly"] = flowRate;
  doc["confidence_score"] = 0.85;

  JsonObject sensorData = doc.createNestedObject("sensor_data");
  sensorData["flow_rate_lpm"] = flowRate;
  sensorData["valve_status"] = valveOpen ? "open" : "closed";
  sensorData["detection_method"] = "flow_based";

  String jsonString;
  serializeJson(doc, jsonString);

  int httpCode = http.POST(jsonString);

  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Leak reported to Supabase");
  } else {
    Serial.print("Failed to report leak. HTTP code: ");
    Serial.println(httpCode);
  }

  http.end();
}

