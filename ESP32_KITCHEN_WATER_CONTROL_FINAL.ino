/*
 * ESP32 Kitchen Water Control System - FINAL VERSION
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
 * 
 * Device ID: ESP_KITCHEN_001
 * Location: Kitchen
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ================= WIFI =================
const char* ssid = "11111111";
const char* password = "11111111";

// ================= SUPABASE =================
const char* supabaseUrl = "https://ituksombwexvutmxcmsv.supabase.co";
const char* supabaseKey =
"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dWtzb21id2V4dnV0bXhjbXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNDIzMjQsImV4cCI6MjA3MTkxODMyNH0.yLAlqs58A7wA__GsKKtZRh7T_WI-AI2UkjPl_SDlbzA";

const char* waterControlTable = "water_connection_control";
const char* commandsTable = "water_connection_commands";
const char* sensorReadingsTable = "sensor_readings";
const char* leakDetectionsTable = "water_leak_detections";

// Device Configuration (Kitchen)
const char* deviceId = "ESP_KITCHEN_001";
const char* deviceName = "Kitchen Water Line";
const char* location = "Kitchen";
const char* segmentId = "e6f043d2-f3ed-4ff4-b1d4-fb925434b7aa";  // Kitchen segment ID
const char* propertyId = "9de4e6db-74ac-4b68-a0d1-290ba7fb50ae"; // Property ID (My Home)

// ================= PINS =================
#define FLOW_SENSOR_PIN 27
#define BUZZER_PIN      25
#define VALVE_PIN       26

// ================= LCD =================
LiquidCrystal_I2C lcd(0x27, 16, 2); // Change I2C address if needed (0x27, 0x3F, or 0x20)

// ================= FLOW VARIABLES =================
volatile unsigned long pulseCount = 0;
unsigned long lastTime = 0;

float flowRate = 0.0;       // L/min (actual sensor reading)
float totalUsed = 0.0;      // Liters

// YF-S201 calibration (adjust based on your sensor)
// Formula: flowRate = (pulses per second * 60) / calibrationFactor
const float calibrationFactor = 7.5; // Pulses per liter per minute

// ================= THRESHOLDS =================
const float leakThreshold = 0.2;   // L/min - leak detected below this
const float startThreshold = 2.0; // L/min - normal flow above this

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

  // Initialize LCD (I2C) - ESP32 default I2C pins: SDA=21, SCL=22
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
    Serial.println("\n=== Sending data to Supabase ===");
    sendSensorReading();
    updateDeviceStatus();
    Serial.println("=== Data send complete ===\n");
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

  // Calculate flow rate: (pulses per second * 60) / calibrationFactor
  // This gives liters per minute
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
    // Line 1: Flow rate and valve status
    lcd.setCursor(0, 0);
    lcd.print("Flow: ");
    lcd.print(flowRate, 2);
    lcd.print(" L/m");
    if (valveOpen) {
      lcd.print(" ON");
    } else {
      lcd.print(" OFF");
    }
    
    // Line 2: Total used and valve status
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
  
  Serial.print("🔵 Registering device... URL: ");
  Serial.println(url);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(1024);
  doc["device_id"] = deviceId;
  doc["device_name"] = deviceName;
  doc["location"] = location;
  doc["property_id"] = propertyId; // Link device to your property (recommended)
  doc["valve_status"] = valveOpen ? "open" : "closed";
  doc["water_flow"] = flowRate; // Use actual sensor reading
  doc["total_water_used"] = totalUsed; // Total water used in liters
  doc["is_online"] = true;
  // last_heartbeat will use database default (now())

  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.print("   JSON: ");
  Serial.println(jsonString);

  int httpCode = http.POST(jsonString);
  
  Serial.print("   HTTP Code: ");
  Serial.println(httpCode);

  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Device registered in Supabase");
  } else if (httpCode == 409) {
    Serial.println("ℹ️ Device already exists, will update...");
    // Try to update instead
    updateDeviceStatus();
  } else {
    Serial.print("❌ Registration FAILED! HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.print("   Response: ");
    if (response.length() > 0) {
      Serial.println(response);
    } else {
      Serial.println("(empty response)");
    }
    Serial.print("   Error: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();
}

void updateDeviceStatus() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(waterControlTable) + 
               "?device_id=eq." + String(deviceId);

  Serial.print("🔵 Updating device status... URL: ");
  Serial.println(url);
  Serial.print("   Flow: ");
  Serial.print(flowRate, 2);
  Serial.print(" L/min, Total: ");
  Serial.print(totalUsed, 2);
  Serial.print(" L, Valve: ");
  Serial.println(valveOpen ? "OPEN" : "CLOSED");

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(768);
  // Keep these stable in case the row was created by SQL / Flutter earlier
  doc["device_name"] = deviceName;
  doc["location"] = location;
  doc["property_id"] = propertyId; // Link device to your property (recommended)
  doc["valve_status"] = valveOpen ? "open" : "closed";
  // Round to 2 decimal places for cleaner JSON
  float roundedFlow = round(flowRate * 100.0) / 100.0;
  float roundedTotal = round(totalUsed * 100.0) / 100.0;
  doc["water_flow"] = roundedFlow;
  doc["total_water_used"] = roundedTotal;
  doc["is_online"] = true;
  // last_heartbeat will use database default (now())

  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.print("   JSON: ");
  Serial.println(jsonString);

  int httpCode = http.PATCH(jsonString);
  
  Serial.print("   HTTP Code: ");
  Serial.println(httpCode);
  
  if (httpCode == 200 || httpCode == 204) {
    Serial.print("✅ Status updated successfully: Flow=");
    Serial.print(flowRate, 2);
    Serial.print(" L/min, Total=");
    Serial.print(totalUsed, 2);
    Serial.print(" L, Valve=");
    Serial.println(valveOpen ? "OPEN" : "CLOSED");
  } else {
    Serial.print("❌ Update FAILED! HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.print("   Response: ");
    if (response.length() > 0) {
      Serial.println(response);
    } else {
      Serial.println("(empty response)");
    }
    Serial.print("   Error details: ");
    Serial.println(http.errorToString(httpCode));
  }
  
  http.end();
}

void sendSensorReading() {
  // Skip sensor readings if not critical - focus on water_connection_control updates
  // This prevents errors if sensor_readings table has strict constraints
  // The main data (flow, total, valve status) is saved in updateDeviceStatus()
  return; // Temporarily disabled to avoid timestamp errors
  
  /* Original code - re-enable after fixing database
  String url = String(supabaseUrl) + "/rest/v1/" + String(sensorReadingsTable);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");

  DynamicJsonDocument doc(512);
  doc["segment_id"] = segmentId;
  // reading_timestamp will use database default (now())
  doc["flow_rate_lpm"] = flowRate; // Actual sensor reading
  doc["sensor_status"] = leakDetected ? "warning" : "normal";

  String jsonString;
  serializeJson(doc, jsonString);

  int httpCode = http.POST(jsonString);
  
  if (httpCode == 201 || httpCode == 200) {
    // Success - data saved silently
  } else {
    Serial.print("⚠️ Sensor reading failed. HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    if (response.length() > 0) {
      Serial.println("Response: " + response);
    }
  }
  
  http.end();
  */
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
  } else if (httpCode != 404) {
    Serial.print("Warning: Command check failed. HTTP code: ");
    Serial.println(httpCode);
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
  } else {
    Serial.print("Unknown command: ");
    Serial.println(commandType);
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
  // executed_at will use database default (now())
  if (!success) {
    doc["error_message"] = "Command execution failed";
  }

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
  // detection_date will use database default (now())
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
    String response = http.getString();
    Serial.println("Response: " + response);
  }

  http.end();
}

