/*
 * ESP32 Water Leak Detection System
 * Detects water leaks using flow-based detection methods:
 * 1. Flow-based detection (unexpected flow when valve is closed)
 * 2. Pressure-based detection (pressure drop indicates leak)
 * 3. Pattern-based detection (sustained abnormal patterns)
 * 
 * Hardware Requirements:
 * - ESP32 Development Board
 * - Water Flow Sensor (YF-S201 or similar) - REQUIRED
 * - Pressure Sensor (MPX5010DP or similar) - Optional but recommended
 * - Relay Module (for automatic valve shutoff on leak detection)
 * - Solenoid Valve (for automatic shutoff)
 * - LCD Display (16x2 or 20x4 I2C) - For status display
 * 
 * Connections (ESP32):
 * - Flow Sensor: GPIO 4 - Pulse input
 * - Pressure Sensor: GPIO 34 (ADC1_CH6) or GPIO 35 (ADC1_CH7) - Analog input
 * - Relay (Valve Control): GPIO 5 - For emergency shutoff
 * - LCD SDA: GPIO 21 (default I2C SDA)
 * - LCD SCL: GPIO 22 (default I2C SCL)
 * - LED Status: GPIO 2 (Built-in LED on most ESP32 boards)
 * - Buzzer: GPIO 14 (optional)
 * 
 * Libraries Required:
 * - WiFi.h (ESP32)
 * - HTTPClient.h (ESP32)
 * - ArduinoJson (v6.x)
 * - LiquidCrystal_I2C (for I2C LCD)
 */

// ========== CONFIGURATION ==========
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase Configuration
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";
const char* sensorReadingsTable = "sensor_readings";
const char* leakDetectionsTable = "water_leak_detections";
const char* notificationsTable = "leak_notifications";

// Device Configuration
const char* deviceId = "LEAK_SENSOR_001";
const char* segmentId = "SEGMENT_001";  // Link to pipeline segment in database
const char* propertyId = "PROPERTY_001"; // Link to property in database
const char* location = "Main Pipeline";

// Pin Definitions (ESP32)
#define FLOW_SENSOR_PIN 4        // GPIO 4 - Flow sensor pulse input
#define PRESSURE_SENSOR_PIN 34   // GPIO 34 (ADC1_CH6) - Analog input for pressure sensor
// Alternative pressure pin: GPIO 35 (ADC1_CH7) - change if needed
#define VALVE_RELAY_PIN 5        // GPIO 5 - Emergency valve shutoff
#define STATUS_LED_PIN 2         // GPIO 2 - Built-in LED (most ESP32 boards)
#define BUZZER_PIN 14            // GPIO 14 - Optional buzzer for alerts


// Flow Sensor Configuration (YF-S201: 1 pulse = 2.25mL)
#define FLOW_PULSE_PER_LITER 450  // 1000mL / 2.25mL = ~450 pulses per liter
volatile unsigned long flowPulseCount = 0;
unsigned long lastFlowRead = 0;
float flowRate = 0.0;  // Liters per minute
float totalWaterUsed = 0.0;  // Total liters

// Pressure Sensor Configuration (MPX5010DP: 0.2V to 4.7V, 0-50 PSI)
#define PRESSURE_SENSOR_MIN_VOLTAGE 0.2
#define PRESSURE_SENSOR_MAX_VOLTAGE 4.7
#define PRESSURE_SENSOR_MAX_PSI 50.0
float currentPressure = 0.0;  // PSI

// Leak Detection Thresholds (Flow-Based Only)
#define MIN_PRESSURE_PSI 10.0      // Minimum normal pressure (adjust based on your system)
#define MAX_FLOW_LPM 15.0          // Maximum normal flow rate (L/min) - no leak expected above this
#define SUSPICIOUS_FLOW_LPM 10.0    // Suspicious flow threshold (L/min)
#define CRITICAL_FLOW_LPM 25.0      // Critical flow threshold (L/min)
#define PRESSURE_DROP_THRESHOLD 5.0  // PSI drop that indicates leak
#define VALVE_CLOSED_FLOW_THRESHOLD 0.5  // Flow > 0.5 L/min when valve closed = leak
#define SUSTAINED_LEAK_TIME_MS 60000  // 1 minute of sustained flow = leak

// Detection Timing
unsigned long lastLeakCheck = 0;
unsigned long lastSensorUpdate = 0;
unsigned long lastLeakAlert = 0;
const unsigned long LEAK_CHECK_INTERVAL = 2000;    // Check every 2 seconds
const unsigned long SENSOR_UPDATE_INTERVAL = 5000; // Update Supabase every 5 seconds
const unsigned long LEAK_ALERT_COOLDOWN = 60000;   // 1 minute between alerts

// Leak Detection State
bool leakDetected = false;
bool valveClosed = false;  // Track if valve is manually closed
bool autoShutoffEnabled = true;  // Automatically close valve on leak detection
String lastLeakType = "";
float lastNormalPressure = 0.0;
unsigned long leakStartTime = 0;
unsigned long sustainedFlowStartTime = 0;
float sustainedFlowRate = 0.0;
unsigned long lastLCDUpdate = 0;
const unsigned long LCD_UPDATE_INTERVAL = 1000;  // Update LCD every second

// WiFi and HTTP (ESP32)
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

WiFiClientSecure client;
HTTPClient http;

// LCD I2C Address - Common addresses: 0x27, 0x3F, 0x20
// If LCD doesn't work, scan for I2C address using I2C scanner sketch
LiquidCrystal_I2C lcd(0x27, 16, 2); // Change 0x27 to your LCD's I2C address if different
bool lcdAvailable = false;

// ========== SETUP ==========
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Water Leak Detection System ===");
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  
  // Initialize pins
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  pinMode(PRESSURE_SENSOR_PIN, INPUT);
  pinMode(VALVE_RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  
  // Start with valve open (relay off = valve open, relay on = valve closed)
  digitalWrite(VALVE_RELAY_PIN, LOW);
  valveClosed = false;
  digitalWrite(STATUS_LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Initialize LCD (I2C)
  // For ESP8266: Uncomment and set your I2C pins if using non-default
  // Wire.begin(4, 5);  // SDA=GPIO4 (D2), SCL=GPIO5 (D1)
  // Wire.begin(5, 14); // Alternative: SDA=GPIO5 (D1), SCL=GPIO14 (D5)
  Wire.begin();  // ESP8266 default or ESP32 uses pins 21, 22
  
  lcd.begin();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Water Leak");
  lcd.setCursor(0, 1);
  lcd.print("Detection Sys");
  delay(2000);
  lcdAvailable = true;
  
  // If LCD doesn't display, try different I2C addresses:
  // Common addresses: 0x27, 0x3F, 0x20
  // Use I2C scanner sketch to find your LCD's address
  
  // Attach interrupt for flow sensor
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), flowPulseCounter, FALLING);
  
  // Connect to WiFi
  updateLCD("Connecting WiFi", "");
  connectToWiFi();
  
  // Initialize Supabase connection
  client.setInsecure();  // For HTTPS (use proper certificate in production)
  
  // Calibrate initial pressure (assume normal pressure on startup)
  delay(2000);
  lastNormalPressure = readPressure();
  Serial.print("Initial pressure: ");
  Serial.print(lastNormalPressure);
  Serial.println(" PSI");
  
  updateLCD("System Ready", "Monitoring...");
  Serial.println("Setup complete!");
  Serial.println("Monitoring for leaks...\n");
}

// ========== MAIN LOOP ==========
void loop() {
  unsigned long currentMillis = millis();
  
  // Read sensors
  calculateFlowRate();
  currentPressure = readPressure();
  
  // Check for leaks
  if (currentMillis - lastLeakCheck >= LEAK_CHECK_INTERVAL) {
    detectLeaks();
    lastLeakCheck = currentMillis;
  }
  
  // Update sensor readings to Supabase
  if (currentMillis - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    sendSensorReading();
    lastSensorUpdate = currentMillis;
  }
  
  // Update LCD display (only if not in alert mode to avoid flickering)
  if (!leakDetected && currentMillis - lastLCDUpdate >= LCD_UPDATE_INTERVAL) {
    updateLCDDisplay();
    lastLCDUpdate = currentMillis;
  } else if (leakDetected && currentMillis - lastLCDUpdate >= 500) {
    // Update more frequently during leak alert
    updateLCDDisplay();
    lastLCDUpdate = currentMillis;
  }
  
  // Handle leak alerts
  if (leakDetected) {
    handleLeakAlert();
  } else {
    // Normal operation - blink LED slowly
    static unsigned long lastBlink = 0;
    if (currentMillis - lastBlink >= 2000) {
      digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
      lastBlink = currentMillis;
    }
  }
  
  delay(100);
}

// ========== LEAK DETECTION LOGIC (Flow-Based Only) ==========
void detectLeaks() {
  bool newLeakDetected = false;
  String leakType = "";
  String severity = "low";
  float estimatedLossRate = 0.0;
  
  // Method 1: Flow When Valve Should Be Closed
  // If valve is closed but flow detected, it's a leak
  if (valveClosed && flowRate > VALVE_CLOSED_FLOW_THRESHOLD) {
    newLeakDetected = true;
    leakType = "continuous";
    severity = flowRate >= CRITICAL_FLOW_LPM ? "critical" : "high";
    estimatedLossRate = flowRate * 60; // L/hour
    Serial.print("⚠️ LEAK DETECTED: Flow when valve closed! ");
    Serial.print(flowRate);
    Serial.println(" L/min");
  }
  
  // Method 2: Excessive Flow Detection (sustained high flow)
  if (flowRate > MAX_FLOW_LPM && !leakDetected) {
    // Check if flow is sustained
    if (sustainedFlowStartTime == 0) {
      sustainedFlowStartTime = millis();
      sustainedFlowRate = flowRate;
    } else {
      unsigned long sustainedDuration = millis() - sustainedFlowStartTime;
      if (sustainedDuration >= SUSTAINED_LEAK_TIME_MS) {  // Sustained flow = leak
        newLeakDetected = true;
        leakType = "continuous";
        severity = flowRate >= CRITICAL_FLOW_LPM ? "critical" : "high";
        estimatedLossRate = flowRate * 60; // L/hour
        Serial.print("⚠️ SUSPICIOUS FLOW DETECTED: ");
        Serial.print(flowRate);
        Serial.print(" L/min for ");
        Serial.print(sustainedDuration / 1000);
        Serial.println(" seconds");
      }
    }
  } else {
    sustainedFlowStartTime = 0;
    sustainedFlowRate = 0.0;
  }
  
  // Method 3: Pressure-Based Detection
  float pressureDrop = lastNormalPressure - currentPressure;
  if (pressureDrop > PRESSURE_DROP_THRESHOLD && currentPressure < MIN_PRESSURE_PSI) {
    // Pressure drop with flow indicates leak
    if (flowRate > 0.5) {
      newLeakDetected = true;
      leakType = "burst";
      severity = pressureDrop > 15.0 ? "critical" : "high";
      estimatedLossRate = (pressureDrop * 2.0) + (flowRate * 60); // Estimate based on pressure drop + flow
      Serial.print("⚠️ PRESSURE DROP DETECTED: ");
      Serial.print(pressureDrop);
      Serial.print(" PSI, Flow: ");
      Serial.print(flowRate);
      Serial.println(" L/min");
    }
  }
  
  // Method 4: Pattern-Based Detection (sustained abnormal flow)
  if (flowRate > SUSPICIOUS_FLOW_LPM && flowRate <= MAX_FLOW_LPM) {
    static unsigned long suspiciousStartTime = 0;
    static int suspiciousCount = 0;
    
    if (suspiciousStartTime == 0) {
      suspiciousStartTime = millis();
      suspiciousCount = 1;
    } else {
      unsigned long suspiciousDuration = millis() - suspiciousStartTime;
      suspiciousCount++;
      
      // If suspicious flow for 3+ minutes with multiple readings
      if (suspiciousDuration >= 180000 && suspiciousCount >= 5) {
        newLeakDetected = true;
        leakType = "intermittent";
        severity = "medium";
        estimatedLossRate = flowRate * 60;
        Serial.println("⚠️ PATTERN-BASED LEAK DETECTED!");
      }
    }
  } else {
    suspiciousStartTime = 0;
    suspiciousCount = 0;
  }
  
  // Method 5: Continuous Low Flow (drip leak)
  // Very low but continuous flow when no water should be used
  if (flowRate > 0.1 && flowRate < 2.0 && !valveClosed) {
    static unsigned long dripStartTime = 0;
    if (dripStartTime == 0) {
      dripStartTime = millis();
    } else {
      unsigned long dripDuration = millis() - dripStartTime;
      // Continuous drip for 10+ minutes = leak
      if (dripDuration >= 600000) {
        newLeakDetected = true;
        leakType = "drip";
        severity = "low";
        estimatedLossRate = flowRate * 60;
        Serial.print("⚠️ DRIP LEAK DETECTED: ");
        Serial.print(flowRate);
        Serial.println(" L/min");
      }
    }
  } else {
    dripStartTime = 0;
  }
  
  // Handle new leak detection
  if (newLeakDetected && !leakDetected) {
    leakDetected = true;
    leakStartTime = millis();
    lastLeakType = leakType;
    
    Serial.println("\n🚨🚨🚨 WATER LEAK DETECTED! 🚨🚨🚨");
    Serial.print("Type: ");
    Serial.println(leakType);
    Serial.print("Severity: ");
    Serial.println(severity);
    Serial.print("Flow Rate: ");
    Serial.print(flowRate);
    Serial.println(" L/min");
    Serial.print("Estimated Loss Rate: ");
    Serial.print(estimatedLossRate);
    Serial.println(" L/hour");
    
    // Report leak to Supabase
    reportLeakToSupabase(leakType, severity, estimatedLossRate);
    
    // Automatic valve shutoff (if enabled)
    if (autoShutoffEnabled) {
      emergencyShutoff();
    }
  }
  
  // Check if leak has been resolved
  if (leakDetected) {
    // Leak resolved if: flow is normal/low, pressure is normal
    bool leakResolved = (flowRate < SUSPICIOUS_FLOW_LPM) &&
                        (currentPressure >= MIN_PRESSURE_PSI - 2.0); // Allow 2 PSI tolerance
    
    if (leakResolved) {
      unsigned long leakDuration = millis() - leakStartTime;
      if (leakDuration > 10000) {  // Only if leak was detected for > 10 seconds
        Serial.println("✅ Leak appears to be resolved");
        leakDetected = false;
        leakStartTime = 0;
        updateLCD("Leak Resolved", "System Normal");
        // You can add logic here to mark leak as resolved in Supabase
      }
    }
  }
}

// ========== SENSOR READING FUNCTIONS ==========
void IRAM_ATTR flowPulseCounter() {
  flowPulseCount++;
}

void calculateFlowRate() {
  unsigned long currentMillis = millis();
  unsigned long timeDelta = currentMillis - lastFlowRead;
  
  if (timeDelta >= 1000) {  // Calculate every second
    float liters = (float)flowPulseCount / FLOW_PULSE_PER_LITER;
    float minutes = timeDelta / 60000.0;
    flowRate = liters / minutes;
    
    totalWaterUsed += liters;
    
    flowPulseCount = 0;
    lastFlowRead = currentMillis;
  }
}

float readPressure() {
  // ESP32 ADC: 12-bit (0-4095), 0-3.3V
  int sensorValue = analogRead(PRESSURE_SENSOR_PIN);
  float voltage = (sensorValue / 4095.0) * 3.3;  // ESP32 ADC: 12-bit, 0-3.3V
  
  // Convert voltage to PSI (adjust formula based on your sensor)
  // For MPX5010DP: Vout = 0.2V + (0.09 * PSI)
  float psi = (voltage - PRESSURE_SENSOR_MIN_VOLTAGE) / 0.09;
  
  // Clamp to valid range
  if (psi < 0) psi = 0;
  if (psi > PRESSURE_SENSOR_MAX_PSI) psi = PRESSURE_SENSOR_MAX_PSI;
  
  return psi;
}

// ========== SUPABASE FUNCTIONS ==========
void connectToWiFi() {
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
    Serial.print("Signal strength (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\nWiFi connection failed!");
    Serial.println("Restarting in 10 seconds...");
    delay(10000);
    ESP.restart();
  }
}

void sendSensorReading() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(sensorReadingsTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(1024);
  doc["segment_id"] = segmentId;
  doc["reading_timestamp"] = "now()";
  doc["pressure_psi"] = currentPressure;
  doc["flow_rate_lpm"] = flowRate;
  doc["sensor_status"] = leakDetected ? "warning" : "normal";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpCode = http.POST(jsonString);
  
  if (httpCode == 201 || httpCode == 200) {
    // Success - reading sent
  } else {
    Serial.print("Failed to send sensor reading. HTTP code: ");
    Serial.println(httpCode);
  }
  
  http.end();
}

void reportLeakToSupabase(String leakType, String severity, float estimatedLossRate) {
  String url = String(supabaseUrl) + "/rest/v1/" + String(leakDetectionsTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(1024);
  doc["property_id"] = propertyId;
  doc["segment_id"] = segmentId;
  doc["detection_date"] = "now()";
  doc["leak_type"] = leakType;
  doc["severity"] = severity;
  doc["status"] = "active";
  doc["location_description"] = location;
  doc["estimated_water_loss_rate"] = estimatedLossRate;
  doc["pressure_drop"] = lastNormalPressure - currentPressure;
  doc["flow_rate_anomaly"] = flowRate;
  doc["confidence_score"] = 0.90;
  
  // Sensor data
  JsonObject sensorData = doc.createNestedObject("sensor_data");
  sensorData["pressure_psi"] = currentPressure;
  sensorData["flow_rate_lpm"] = flowRate;
  sensorData["valve_closed"] = valveClosed;
  sensorData["detection_method"] = "flow_based";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpCode = http.POST(jsonString);
  
  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Leak reported to Supabase successfully!");
    
    // Create notification
    String response = http.getString();
    DynamicJsonDocument responseDoc(512);
    deserializeJson(responseDoc, response);
    String leakDetectionId = responseDoc["id"].as<String>();
    
    createLeakNotification(leakDetectionId, severity);
  } else {
    Serial.print("❌ Failed to report leak. HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.println("Response: " + response);
  }
  
  http.end();
}

void createLeakNotification(String leakDetectionId, String severity) {
  String url = String(supabaseUrl) + "/rest/v1/" + String(notificationsTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(512);
  doc["leak_detection_id"] = leakDetectionId;
  doc["notification_type"] = "in_app";
  doc["title"] = "🚨 Water Leak Detected!";
  doc["message"] = "A " + String(severity) + " severity leak was detected at " + String(location);
  doc["severity"] = severity;
  doc["is_sent"] = true;
  doc["sent_at"] = "now()";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  http.POST(jsonString);
  http.end();
}

// ========== VALVE CONTROL ==========
void emergencyShutoff() {
  Serial.println("🛑 EMERGENCY SHUTOFF ACTIVATED!");
  digitalWrite(VALVE_RELAY_PIN, HIGH);  // Close valve
  valveClosed = true;
  digitalWrite(STATUS_LED_PIN, HIGH);    // LED on for alert
  digitalWrite(BUZZER_PIN, HIGH);       // Sound buzzer
  
  updateLCD("EMERGENCY SHUTOFF", "Valve Closed");
  
  // Log emergency shutoff
  Serial.println("Valve closed to prevent water loss");
}

void handleLeakAlert() {
  unsigned long currentMillis = millis();
  
  // Rapid LED blinking for leak alert
  static unsigned long lastBlink = 0;
  if (currentMillis - lastBlink >= 200) {
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
    lastBlink = currentMillis;
  }
  
  // Periodic buzzer beep
  static unsigned long lastBeep = 0;
  if (currentMillis - lastBeep >= 2000) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    lastBeep = currentMillis;
  }
  
  // Print status every 10 seconds
  static unsigned long lastStatusPrint = 0;
  if (currentMillis - lastStatusPrint >= 10000) {
    Serial.println("\n--- Leak Status ---");
    Serial.print("Type: ");
    Serial.println(lastLeakType);
    Serial.print("Flow Rate: ");
    Serial.print(flowRate);
    Serial.println(" L/min");
    Serial.print("Pressure: ");
    Serial.print(currentPressure);
    Serial.println(" PSI");
    Serial.println("-------------------\n");
    lastStatusPrint = currentMillis;
  }
}

// ========== LCD DISPLAY FUNCTIONS ==========
void updateLCD(String line1, String line2) {
  if (!lcdAvailable) return;
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1.substring(0, 16));  // Limit to 16 characters
  lcd.setCursor(0, 1);
  lcd.print(line2.substring(0, 16));  // Limit to 16 characters
}

void updateLCDDisplay() {
  if (!lcdAvailable) return;
  
  if (leakDetected) {
    // Show leak alert
    String line1 = "LEAK DETECTED!";
    String line2 = "Flow: " + String(flowRate, 1) + "L/min";
    updateLCD(line1, line2);
  } else {
    // Show normal status
    String line1 = "Flow: " + String(flowRate, 1) + " L/min";
    String line2 = "Press: " + String(currentPressure, 1) + " PSI";
    updateLCD(line1, line2);
  }
}

// ========== UTILITY FUNCTIONS ==========
void printStatus() {
  Serial.println("\n=== Leak Detection System Status ===");
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  Serial.print("Leak Detected: ");
  Serial.println(leakDetected ? "YES 🚨" : "NO ✅");
  Serial.print("Flow Rate: ");
  Serial.print(flowRate);
  Serial.println(" L/min");
  Serial.print("Pressure: ");
  Serial.print(currentPressure);
  Serial.println(" PSI");
  Serial.print("Valve Status: ");
  Serial.println(valveClosed ? "CLOSED" : "OPEN");
  Serial.print("WiFi Status: ");
  Serial.println(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
  Serial.println("====================================\n");
}

