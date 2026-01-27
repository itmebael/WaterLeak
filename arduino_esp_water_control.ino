/*
 * ESP8266/ESP32 Water Connection Control
 * Controls water valve via relay and reads water flow sensor
 * Communicates with Supabase for remote control
 * 
 * Hardware Requirements:
 * - ESP8266 (NodeMCU) or ESP32
 * - Relay Module (for solenoid valve control)
 * - Water Flow Sensor (YF-S201 or similar)
 * - Optional: Pressure sensor, Temperature sensor
 * 
 * Connections:
 * - Relay: GPIO 5 (D1 on NodeMCU) - Controls valve
 * - Flow Sensor: GPIO 4 (D2 on NodeMCU) - Pulse input
 * - LED Status: GPIO 2 (Built-in LED on NodeMCU)
 * 
 * Libraries Required:
 * - ESP8266WiFi (or WiFi.h for ESP32)
 * - ESP8266HTTPClient (or HTTPClient.h for ESP32)
 * - ArduinoJson (v6.x)
 */

// ========== CONFIGURATION ==========
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase Configuration
const char* supabaseUrl = "https://YOUR_PROJECT_ID.supabase.co";
const char* supabaseKey = "YOUR_SUPABASE_ANON_KEY";
const char* supabaseTable = "water_connection_control";
const char* commandsTable = "water_connection_commands";
const char* logsTable = "water_connection_logs";

// Device Configuration
const char* deviceId = "ESP_001";  // Unique identifier for this ESP device
const char* deviceName = "Main Water Line";
const char* location = "Main Entry";

// Pin Definitions
#define VALVE_RELAY_PIN 5      // GPIO 5 (D1) - Controls solenoid valve
#define FLOW_SENSOR_PIN 4      // GPIO 4 (D2) - Flow sensor pulse input
#define STATUS_LED_PIN 2       // GPIO 2 - Built-in LED
#define PRESSURE_SENSOR_PIN A0 // Analog pin for pressure (optional)

// Flow Sensor Configuration (YF-S201: 1 pulse = 2.25mL)
#define FLOW_PULSE_PER_LITER 450  // 1000mL / 2.25mL = ~450 pulses per liter
volatile unsigned long flowPulseCount = 0;
unsigned long lastFlowRead = 0;
float flowRate = 0.0;  // Liters per minute
float totalWaterUsed = 0.0;  // Total liters

// Timing Configuration
unsigned long lastHeartbeat = 0;
unsigned long lastCommandCheck = 0;
unsigned long lastFlowUpdate = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000;    // 30 seconds
const unsigned long COMMAND_CHECK_INTERVAL = 5000; // 5 seconds
const unsigned long FLOW_UPDATE_INTERVAL = 1000;  // 1 second

// Valve State
bool currentValveState = false;  // false = closed, true = open
bool lastValveState = false;

// WiFi and HTTP
#include <ESP8266WiFi.h>  // Use WiFi.h for ESP32
#include <ESP8266HTTPClient.h>  // Use HTTPClient.h for ESP32
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>

WiFiClientSecure client;
HTTPClient http;

// ========== SETUP ==========
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== Water Connection Control System ===");
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  
  // Initialize pins
  pinMode(VALVE_RELAY_PIN, OUTPUT);
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(VALVE_RELAY_PIN, LOW);  // Start with valve closed
  digitalWrite(STATUS_LED_PIN, LOW);
  
  // Attach interrupt for flow sensor
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), flowPulseCounter, FALLING);
  
  // Connect to WiFi
  connectToWiFi();
  
  // Initialize Supabase connection
  client.setInsecure();  // For HTTPS (use proper certificate in production)
  
  // Register device in Supabase
  registerDevice();
  
  // Get initial valve state from Supabase
  getValveStateFromSupabase();
  
  Serial.println("Setup complete!");
  Serial.println("System ready...\n");
}

// ========== MAIN LOOP ==========
void loop() {
  unsigned long currentMillis = millis();
  
  // Check for commands from Supabase
  if (currentMillis - lastCommandCheck >= COMMAND_CHECK_INTERVAL) {
    checkForCommands();
    lastCommandCheck = currentMillis;
  }
  
  // Update flow rate calculation
  if (currentMillis - lastFlowUpdate >= FLOW_UPDATE_INTERVAL) {
    calculateFlowRate();
    lastFlowUpdate = currentMillis;
  }
  
  // Send heartbeat to Supabase
  if (currentMillis - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = currentMillis;
  }
  
  // Log valve state changes
  if (currentValveState != lastValveState) {
    logValveStateChange();
    lastValveState = currentValveState;
  }
  
  // Blink LED to show system is running
  static unsigned long lastBlink = 0;
  if (currentMillis - lastBlink >= 1000) {
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
    lastBlink = currentMillis;
  }
  
  delay(100);
}

// ========== WIFI CONNECTION ==========
void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed!");
    Serial.println("Retrying in 10 seconds...");
    delay(10000);
    ESP.restart();
  }
}

// ========== SUPABASE FUNCTIONS ==========
void registerDevice() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(supabaseTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(1024);
  doc["device_id"] = deviceId;
  doc["device_name"] = deviceName;
  doc["location"] = location;
  doc["valve_status"] = "closed";
  doc["water_flow"] = 0.0;
  doc["is_online"] = true;
  doc["last_heartbeat"] = "now()";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpCode = http.POST(jsonString);
  
  if (httpCode == 201 || httpCode == 200) {
    Serial.println("Device registered successfully!");
  } else if (httpCode == 409) {
    Serial.println("Device already exists, updating...");
    updateDeviceStatus();
  } else {
    Serial.print("Registration failed. HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.println("Response: " + response);
  }
  
  http.end();
}

void updateDeviceStatus() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(supabaseTable) + "?device_id=eq." + String(deviceId);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(512);
  doc["valve_status"] = currentValveState ? "open" : "closed";
  doc["water_flow"] = flowRate;
  doc["is_online"] = true;
  doc["last_heartbeat"] = "now()";
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpCode = http.PATCH(jsonString);
  
  if (httpCode == 200 || httpCode == 204) {
    Serial.println("Device status updated!");
  } else {
    Serial.print("Update failed. HTTP code: ");
    Serial.println(httpCode);
  }
  
  http.end();
}

void sendHeartbeat() {
  updateDeviceStatus();
  
  // Also log heartbeat event
  logEvent("heartbeat", "");
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
      // Parse JSON array
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
  } else if (httpCode != 200 && httpCode != 404) {
    Serial.print("Command check failed. HTTP code: ");
    Serial.println(httpCode);
  }
  
  http.end();
}

bool executeCommand(String commandType) {
  bool success = false;
  
  if (commandType == "open_valve") {
    openValve();
    success = true;
  } else if (commandType == "close_valve") {
    closeValve();
    success = true;
  } else if (commandType == "get_status") {
    updateDeviceStatus();
    success = true;
  }
  
  return success;
}

void updateCommandStatus(String commandId, bool success) {
  String url = String(supabaseUrl) + "/rest/v1/" + String(commandsTable) + "?id=eq." + commandId;
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(256);
  doc["status"] = success ? "executed" : "failed";
  doc["executed_at"] = "now()";
  if (!success) {
    doc["error_message"] = "Command execution failed";
  }
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  http.PATCH(jsonString);
  http.end();
}

void getValveStateFromSupabase() {
  String url = String(supabaseUrl) + "/rest/v1/" + String(supabaseTable) + 
               "?device_id=eq." + String(deviceId) + 
               "&select=valve_status";
  
  http.begin(client, url);
  http.addHeader("apikey", supabaseKey);
  
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(256);
    deserializeJson(doc, payload);
    
    if (doc.is<JsonArray>() && doc.size() > 0) {
      String valveStatus = doc[0]["valve_status"].as<String>();
      if (valveStatus == "open") {
        openValve();
      } else {
        closeValve();
      }
      Serial.print("Valve state from Supabase: ");
      Serial.println(valveStatus);
    }
  }
  
  http.end();
}

// ========== VALVE CONTROL ==========
void openValve() {
  digitalWrite(VALVE_RELAY_PIN, HIGH);
  currentValveState = true;
  Serial.println("Valve OPENED");
  updateDeviceStatus();
  logEvent("valve_opened", "");
}

void closeValve() {
  digitalWrite(VALVE_RELAY_PIN, LOW);
  currentValveState = false;
  Serial.println("Valve CLOSED");
  updateDeviceStatus();
  logEvent("valve_closed", "");
}

// ========== FLOW SENSOR ==========
void IRAM_ATTR flowPulseCounter() {
  flowPulseCount++;
}

void calculateFlowRate() {
  unsigned long currentMillis = millis();
  unsigned long timeDelta = currentMillis - lastFlowRead;
  
  if (timeDelta >= 1000) {  // Calculate every second
    // Calculate flow rate: (pulses / pulses_per_liter) / (time in minutes)
    float liters = (float)flowPulseCount / FLOW_PULSE_PER_LITER;
    float minutes = timeDelta / 60000.0;
    flowRate = liters / minutes;
    
    totalWaterUsed += liters;
    
    // Reset counter
    flowPulseCount = 0;
    lastFlowRead = currentMillis;
    
    // Log flow if valve is open and flow detected
    if (currentValveState && flowRate > 0.1) {
      logFlowEvent();
    }
  }
}

// ========== LOGGING ==========
void logEvent(String eventType, String additionalData) {
  String url = String(supabaseUrl) + "/rest/v1/" + String(logsTable);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  
  DynamicJsonDocument doc(512);
  doc["device_id"] = deviceId;
  doc["event_type"] = eventType;
  doc["valve_status"] = currentValveState ? "open" : "closed";
  doc["water_flow"] = flowRate;
  doc["created_at"] = "now()";
  
  if (additionalData.length() > 0) {
    doc["event_data"] = additionalData;
  }
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  http.POST(jsonString);
  http.end();
}

void logValveStateChange() {
  String eventType = currentValveState ? "valve_opened" : "valve_closed";
  logEvent(eventType, "");
}

void logFlowEvent() {
  logEvent("flow_detected", "");
}

// ========== UTILITY FUNCTIONS ==========
void printStatus() {
  Serial.println("\n=== Device Status ===");
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  Serial.print("Valve Status: ");
  Serial.println(currentValveState ? "OPEN" : "CLOSED");
  Serial.print("Flow Rate: ");
  Serial.print(flowRate);
  Serial.println(" L/min");
  Serial.print("Total Water Used: ");
  Serial.print(totalWaterUsed);
  Serial.println(" L");
  Serial.print("WiFi Status: ");
  Serial.println(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
  Serial.println("====================\n");
}



