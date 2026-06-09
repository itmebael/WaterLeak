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
 const char* supabaseUrl = "https://pcddnhsvxjnwwmwchujk.supabase.co";
 const char* supabaseKey =
 "sb_publishable_FUK89NzP96SBBnOsgbIeZg_yX0Conps";
 
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
#define WATER_SENSOR_1_PIN 32  // Analog pin for water sensor 1
#define WATER_SENSOR_2_PIN 33  // Analog pin for water sensor 2
 
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
 const float minFlowForCounting = 0.5; // L/min - minimum flow to count in totalUsed (prevents counting leaks/noise)
 
// ================= WATER SENSOR VARIABLES =================
int waterSensor1Value = 0;        // Raw ADC reading (0-4095 for ESP32)
int waterSensor2Value = 0;        // Raw ADC reading (0-4095 for ESP32)
float waterSensor1Percent = 0.0;  // Water detection percentage (0-100%)
float waterSensor2Percent = 0.0;  // Water detection percentage (0-100%)
bool waterSensor1Detected = false; // True if sensor 1 detects water (>= 25%)
bool waterSensor2Detected = false; // True if sensor 2 detects water (>= 25%)
bool waterLeakDetected = false;    // True if either sensor detects water
unsigned long waterLeakStartTime = 0; // When water leak was first detected
// Water sensor calibration values (ESP32 ADC: 0-4095)
// Note: These values need to be calibrated based on your actual sensor readings
// When DRY: sensor reads HIGH (higher ADC value)
// When WET: sensor reads LOW (lower ADC value)
const int WATER_SENSOR_DRY_VALUE = 4095;   // ADC value when sensor is completely dry (max value)
const int WATER_SENSOR_WET_VALUE = 0;       // ADC value when sensor is fully wet (min value)
const float WATER_DETECTION_THRESHOLD = 25.0; // Close valve if sensor reads >= 25% (1-25% = dry/OK, 25-100% = wet/leak)

// Auto-calibration: Track min/max values seen to adjust calibration
int waterSensor1Min = 4095;  // Track minimum value (wettest)
int waterSensor1Max = 0;      // Track maximum value (driest)
int waterSensor2Min = 4095;
int waterSensor2Max = 0;
bool calibrationMode = true;  // Auto-calibrate for first 30 seconds

// ================= SYSTEM STATE =================
bool valveOpen = false;           // Current valve state
bool leakDetected = false;
bool autoControlEnabled = true;   // Auto valve control based on flow
unsigned long lastSupabaseUpdate = 0;
unsigned long lastCommandCheck = 0;
unsigned long leakStartTime = 0;
unsigned long systemStartTime = 0;  // Track when system started
bool systemStabilized = false;      // Ignore readings until stabilized
unsigned long flowStartTime = 0;     // Track when flow started (for sustained flow check)
bool flowConfirmed = false;          // Flow must be sustained before counting
 
 // Timing intervals
 const unsigned long SUPABASE_UPDATE_INTERVAL = 5000;  // 5 seconds
 const unsigned long COMMAND_CHECK_INTERVAL = 3000;    // 3 seconds
 const unsigned long LEAK_ALERT_DURATION = 10000;       // 10 seconds
 const unsigned long STABILIZATION_PERIOD = 5000;      // 5 seconds - ignore readings during startup
 const unsigned long FLOW_CONFIRMATION_TIME = 3000;    // 3 seconds - flow must be sustained before counting
 const float MIN_FLOW_THRESHOLD = 0.05;                // Ignore flow below this (noise)
 
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
  pinMode(WATER_SENSOR_1_PIN, INPUT);  // Analog input
  pinMode(WATER_SENSOR_2_PIN, INPUT);  // Analog input
 
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
   client.setTimeout(10000); // 10 second timeout for connections
 
   // Register device in Supabase
   registerDevice();
 
   lastTime = millis();
   lastSupabaseUpdate = millis();
   lastCommandCheck = millis();
   systemStartTime = millis();  // Record startup time
   systemStabilized = false;    // Will be true after stabilization period
 
   lcd.clear();
   lcd.setCursor(0, 0);
   lcd.print("Kitchen Ready");
   lcd.setCursor(0, 1);
   lcd.print("Monitoring...");
 
   Serial.println("Setup complete!");
   Serial.println("System ready...\n");
   Serial.println("Stabilization period: 5 seconds (ignoring initial readings)");
 }
 
 // ================= MAIN LOOP =================
 void loop() {
   unsigned long currentMillis = millis();
 
   // Check if system has stabilized (ignore readings for first 5 seconds)
   if (!systemStabilized && (currentMillis - systemStartTime >= STABILIZATION_PERIOD)) {
     systemStabilized = true;
     Serial.println("✅ System stabilized - starting normal operation");
     // Reset flow counters after stabilization
     flowRate = 0.0;
     totalUsed = 0.0;
   }
 
   // Calculate flow rate every second
   if (currentMillis - lastTime >= 1000) {
     calculateFlowRate();
     lastTime = currentMillis;
 
     // Update LCD display
     updateLCD();
 
    // Read water sensors
    readWaterSensors();
    
    // Leak detection and valve control (only if stabilized)
    if (systemStabilized) {
      detectWaterLeak();  // Check water sensors first
      
      // CRITICAL SAFETY CHECK: If ANY sensor is WET (>= 25%), FORCE CLOSE valve immediately
      // This overrides all other logic to ensure safety
      if (waterSensor1Percent >= 25.0 || waterSensor2Percent >= 25.0) {
        if (valveOpen) {
          closeValve();
          Serial.println("🚨 EMERGENCY: Valve FORCED CLOSED - Water sensor leak detected!");
          if (waterSensor1Percent >= 25.0) {
            Serial.print("   ⚠️ Sensor 1: ");
            Serial.print(waterSensor1Percent, 1);
            Serial.println("% (WET-LEAK >= 25%)");
          }
          if (waterSensor2Percent >= 25.0) {
            Serial.print("   ⚠️ Sensor 2: ");
            Serial.print(waterSensor2Percent, 1);
            Serial.println("% (WET-LEAK >= 25%)");
          }
        }
        // CRITICAL: Ensure buzzer is ON when sensors detect leak
        // This safety check ensures buzzer stays ON even if other code tries to turn it off
        if (digitalRead(BUZZER_PIN) == LOW) {
          Serial.println("🔔 FORCING BUZZER ON - Water sensor leak active!");
          digitalWrite(BUZZER_PIN, HIGH);
        }
      } else {
        // Sensors are DRY (< 25%) - FORCE buzzer OFF immediately
        // This is a critical safety check to ensure buzzer stops when sensors are dry
        if (digitalRead(BUZZER_PIN) == HIGH) {
          Serial.println("🔇 EMERGENCY: FORCING BUZZER OFF - Sensors are dry (<25%)");
          digitalWrite(BUZZER_PIN, LOW);
        }
      }
      
      detectLeakAndControlValve();  // Then check flow-based leak
    }
 
    // Serial debug
    Serial.print("Flow: ");
    Serial.print(flowRate, 2);
    Serial.print(" L/min | Total: ");
    Serial.print(totalUsed, 2);
    Serial.print(" L | Valve: ");
    Serial.print(valveOpen ? "OPEN" : "CLOSED");
    Serial.print(" | Water S1: ");
    Serial.print(waterSensor1Percent, 1);
    Serial.print("% (ADC:");
    Serial.print(waterSensor1Value);
    Serial.print(") S2: ");
    Serial.print(waterSensor2Percent, 1);
    Serial.print("% (ADC:");
    Serial.print(waterSensor2Value);
    Serial.print(")");
    if (!systemStabilized) {
      Serial.print(" [STABILIZING]");
    }
    if (calibrationMode && systemStabilized) {
      Serial.print(" [CALIBRATING]");
    }
    Serial.println();
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
   
   // Ignore very small flow readings (noise)
   if (flowRate < MIN_FLOW_THRESHOLD) {
     flowRate = 0.0;
   }
   
   unsigned long currentMillis = millis();
   
   // Check if flow is sustained (not just a brief spike)
   if (systemStabilized && valveOpen && flowRate > minFlowForCounting) {
     // Flow detected - check if it's sustained
     if (!flowConfirmed) {
       // First time detecting flow above threshold
       if (flowStartTime == 0) {
         flowStartTime = currentMillis;
       } else if (currentMillis - flowStartTime >= FLOW_CONFIRMATION_TIME) {
         // Flow has been sustained for required time
         flowConfirmed = true;
         Serial.println("✅ Flow confirmed - starting to count");
       }
     }
     
     // Only count if flow is confirmed (sustained for 3+ seconds)
     if (flowConfirmed) {
       totalUsed += flowRate / 60.0; // Add liters per second
     }
   } else {
     // No flow or valve closed - reset flow confirmation
     if (flowConfirmed || flowStartTime > 0) {
       flowConfirmed = false;
       flowStartTime = 0;
       if (flowRate == 0.0 || !valveOpen) {
         // Only log if flow actually stopped (not just below threshold)
         if (flowRate == 0.0) {
           Serial.println("⏸️ Flow stopped - resetting confirmation");
         }
       }
     }
   }
 }
 
// ================= WATER SENSOR FUNCTIONS =================
void readWaterSensors() {
  // Read analog values from water sensors (ESP32 has 12-bit ADC: 0-4095)
  waterSensor1Value = analogRead(WATER_SENSOR_1_PIN);
  waterSensor2Value = analogRead(WATER_SENSOR_2_PIN);
  
  // Auto-calibration: Track min/max during first 30 seconds
  if (calibrationMode && systemStabilized) {
    static unsigned long calibrationStartTime = 0;
    if (calibrationStartTime == 0) {
      calibrationStartTime = millis();
      Serial.println("🔧 Starting water sensor calibration (30 seconds)...");
    }
    
    // Update min/max values
    if (waterSensor1Value < waterSensor1Min) waterSensor1Min = waterSensor1Value;
    if (waterSensor1Value > waterSensor1Max) waterSensor1Max = waterSensor1Value;
    if (waterSensor2Value < waterSensor2Min) waterSensor2Min = waterSensor2Value;
    if (waterSensor2Value > waterSensor2Max) waterSensor2Max = waterSensor2Value;
    
    // End calibration after 30 seconds
    if (millis() - calibrationStartTime >= 30000) {
      calibrationMode = false;
      Serial.println("✅ Calibration complete!");
      Serial.print("   Sensor 1 - Min (wet): ");
      Serial.print(waterSensor1Min);
      Serial.print(", Max (dry): ");
      Serial.println(waterSensor1Max);
      Serial.print("   Sensor 2 - Min (wet): ");
      Serial.print(waterSensor2Min);
      Serial.print(", Max (dry): ");
      Serial.println(waterSensor2Max);
    }
  }
  
  // Calculate percentage: 100% = DRY (no water), 0% = WET (water detected)
  // Most water sensors: HIGH ADC = DRY, LOW ADC = WET
  // Formula: percent = ((current - min_wet) / (max_dry - min_wet)) * 100
  // We want: 100% = dry (no leak), 0% = wet (leak detected)
  
  if (calibrationMode) {
    // During calibration, use default values
    // High ADC (dry) = 100%, Low ADC (wet) = 0%
    waterSensor1Percent = (waterSensor1Value / 4095.0) * 100.0;
    waterSensor2Percent = (waterSensor2Value / 4095.0) * 100.0;
  } else {
    // Use calibrated min/max values
    int range1 = waterSensor1Max - waterSensor1Min;
    int range2 = waterSensor2Max - waterSensor2Min;
    
    if (range1 > 100) {  // Only use calibration if we have a good range
      // Map: max (dry) = 100%, min (wet) = 0%
      waterSensor1Percent = ((float)(waterSensor1Value - waterSensor1Min) / (float)range1) * 100.0;
    } else {
      // Fallback to default calculation
      waterSensor1Percent = (waterSensor1Value / 4095.0) * 100.0;
    }
    
    if (range2 > 100) {
      waterSensor2Percent = ((float)(waterSensor2Value - waterSensor2Min) / (float)range2) * 100.0;
    } else {
      waterSensor2Percent = (waterSensor2Value / 4095.0) * 100.0;
    }
  }
  
  // Clamp values between 0 and 100
  if (waterSensor1Percent < 0) waterSensor1Percent = 0;
  if (waterSensor1Percent > 100) waterSensor1Percent = 100;
  if (waterSensor2Percent < 0) waterSensor2Percent = 0;
  if (waterSensor2Percent > 100) waterSensor2Percent = 100;
  
  // Detection logic: >= 25% = WET/LEAK, < 25% = DRY/OK
  // 1-25% = DRY state (no leak, OK)
  // 25-100% = WET state (leak detected, buzzer ON, valve CLOSED)
  waterSensor1Detected = (waterSensor1Percent >= WATER_DETECTION_THRESHOLD);
  waterSensor2Detected = (waterSensor2Percent >= WATER_DETECTION_THRESHOLD);
  
  // Debug output every 5 seconds to show raw values
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug >= 5000) {
    Serial.print("🔍 Sensor Debug - S1 ADC: ");
    Serial.print(waterSensor1Value);
    Serial.print(" (");
    Serial.print(waterSensor1Percent, 1);
    Serial.print("%) | S2 ADC: ");
    Serial.print(waterSensor2Value);
    Serial.print(" (");
    Serial.print(waterSensor2Percent, 1);
    Serial.println("%)");
    lastDebug = millis();
  }
}

void detectWaterLeak() {
  if (!autoControlEnabled || !systemStabilized) return;
  
  // INDEPENDENT SENSOR DETECTION: Each sensor works independently
  // 1-25% = DRY state (no leak)
  // 25-100% = WET state (leak detected)
  
  // Check each sensor independently
  bool sensor1Leak = waterSensor1Detected;  // Sensor 1 leak status
  bool sensor2Leak = waterSensor2Detected;  // Sensor 2 leak status
  
  // Overall leak status: true if ANY sensor detects leak
  bool newWaterLeak = (sensor1Leak || sensor2Leak);
  
  // Debug output every 2 seconds to help diagnose buzzer issues
  static unsigned long lastDebugOutput = 0;
  if (millis() - lastDebugOutput >= 2000) {
    Serial.print("🔍 Water sensor status - S1: ");
    Serial.print(waterSensor1Percent, 1);
    Serial.print("% (");
    Serial.print(sensor1Leak ? "LEAK" : "OK");
    Serial.print(") S2: ");
    Serial.print(waterSensor2Percent, 1);
    Serial.print("% (");
    Serial.print(sensor2Leak ? "LEAK" : "OK");
    Serial.print(") | Buzzer: ");
    Serial.print(digitalRead(BUZZER_PIN) ? "ON" : "OFF");
    Serial.print(" | WaterLeak: ");
    Serial.println(waterLeakDetected ? "YES" : "NO");
    lastDebugOutput = millis();
  }
  
  // Handle Sensor 1 independently
  static bool sensor1LeakActive = false;
  static unsigned long sensor1LeakStartTime = 0;
  
  if (sensor1Leak) {
    if (!sensor1LeakActive) {
      // Sensor 1 first detected leak
      sensor1LeakActive = true;
      sensor1LeakStartTime = millis();
      Serial.println("🚨 SENSOR 1: WATER LEAK DETECTED!");
      Serial.print("   Sensor 1: ");
      Serial.print(waterSensor1Percent, 1);
      Serial.println("% (WET-LEAK)");
      
      // Close valve immediately (independent action)
      closeValve();
      
      // Update LCD immediately to show leak
      updateLCD();
      
      // Report Sensor 1 leak to Supabase
      reportWaterLeakToSupabase();
    }
  } else {
    if (sensor1LeakActive) {
      // Sensor 1 leak cleared
      sensor1LeakActive = false;
      Serial.println("✅ SENSOR 1: Leak cleared - sensor is dry (<25%)");
    }
  }
  
  // Handle Sensor 2 independently
  static bool sensor2LeakActive = false;
  static unsigned long sensor2LeakStartTime = 0;
  
  if (sensor2Leak) {
    if (!sensor2LeakActive) {
      // Sensor 2 first detected leak
      sensor2LeakActive = true;
      sensor2LeakStartTime = millis();
      Serial.println("🚨 SENSOR 2: WATER LEAK DETECTED!");
      Serial.print("   Sensor 2: ");
      Serial.print(waterSensor2Percent, 1);
      Serial.println("% (WET-LEAK)");
      
      // Close valve immediately (independent action)
      closeValve();
      
      // Update LCD immediately to show leak
      updateLCD();
      
      // Report Sensor 2 leak to Supabase
      reportWaterLeakToSupabase();
    }
  } else {
    if (sensor2LeakActive) {
      // Sensor 2 leak cleared
      sensor2LeakActive = false;
      Serial.println("✅ SENSOR 2: Leak cleared - sensor is dry (<25%)");
    }
  }
  
  // Update overall leak status - MUST be set based on actual sensor readings
  // Store previous state BEFORE updating to detect state changes
  bool previousLeakStatus = waterLeakDetected;
  waterLeakDetected = newWaterLeak;
  
  // Buzzer control: ON if ANY sensor detects leak
  // Buzzer should STAY ON continuously while sensor detects leak (>= 25%)
  if (newWaterLeak) {
    // At least one sensor has leak (>= 25%)
    if (!previousLeakStatus) {
      // First time detecting water leak (either sensor)
      waterLeakStartTime = millis();
      Serial.println("🔔 BUZZER ON - Water leak detected!");
      digitalWrite(BUZZER_PIN, HIGH);  // Turn buzzer ON
      // Update LCD immediately to show leak
      updateLCD();
    } else {
      // Continue beeping alarm - keep buzzer ON and beep every 500ms
      // This ensures buzzer stays active while leak is detected
      static unsigned long lastBeep = 0;
      if (millis() - lastBeep >= 500) {
        // Toggle buzzer to create beeping sound (ON/OFF every 500ms)
        digitalWrite(BUZZER_PIN, !digitalRead(BUZZER_PIN));
        lastBeep = millis();
      }
      // CRITICAL: Ensure buzzer is ON if it was accidentally turned off
      // Force buzzer ON if it's in the ON phase of the beep cycle
      unsigned long timeSinceLastBeep = millis() - lastBeep;
      if (digitalRead(BUZZER_PIN) == LOW && timeSinceLastBeep < 250) {
        // It's in the ON phase (first 250ms of 500ms cycle) - force ON
        digitalWrite(BUZZER_PIN, HIGH);
      }
      // Also ensure buzzer is ON if it's been OFF for too long (safety check)
      if (digitalRead(BUZZER_PIN) == LOW && timeSinceLastBeep > 400) {
        // Almost time for next beep - ensure it's ready
        digitalWrite(BUZZER_PIN, HIGH);
      }
    }
  } else {
    // No water detected (both sensors are dry, < 25%) - IMMEDIATELY clear leak
    if (previousLeakStatus) {
      // Both sensors are now dry (< 25%) - leak was just cleared
      Serial.println("✅ All sensors dry - leak cleared IMMEDIATELY (<25%)");
      Serial.print("   Sensor 1: ");
      Serial.print(waterSensor1Percent, 1);
      Serial.print("% | Sensor 2: ");
      Serial.print(waterSensor2Percent, 1);
      Serial.println("% - Both sensors are DRY");
      Serial.println("🔇 Buzzer OFF - Valve can now open if flow is normal");
    }
    // CRITICAL: Always ensure buzzer is OFF when all sensors are dry (< 25%)
    // Force turn off buzzer immediately - no beeping when sensors are dry
    if (digitalRead(BUZZER_PIN) == HIGH) {
      Serial.println("🔇 FORCING BUZZER OFF - Sensors are dry (<25%)");
      digitalWrite(BUZZER_PIN, LOW);
    }
  }
  
  // Debug: Log if there's a mismatch (should never happen now)
  if (waterLeakDetected && !newWaterLeak) {
    Serial.println("⚠️ WARNING: waterLeakDetected is TRUE but sensors are dry!");
    Serial.print("   S1: ");
    Serial.print(waterSensor1Percent, 1);
    Serial.print("% (detected: ");
    Serial.print(waterSensor1Detected ? "YES" : "NO");
    Serial.print(") S2: ");
    Serial.print(waterSensor2Percent, 1);
    Serial.print("% (detected: ");
    Serial.print(waterSensor2Detected ? "YES" : "NO");
    Serial.println(")");
    // Force clear the leak and turn off buzzer
    waterLeakDetected = false;
    Serial.println("🔇 FORCING BUZZER OFF - Mismatch detected, sensors are dry!");
    digitalWrite(BUZZER_PIN, LOW);
  }
  
  // FINAL SAFETY CHECK: If sensors are dry (< 25%), buzzer MUST be OFF
  // This ensures buzzer is always OFF when sensors are dry, regardless of other logic
  if (!newWaterLeak && digitalRead(BUZZER_PIN) == HIGH) {
    Serial.println("🔇 FINAL SAFETY CHECK: Forcing buzzer OFF - sensors are dry!");
    digitalWrite(BUZZER_PIN, LOW);
  }
}

// ================= LEAK DETECTION & VALVE CONTROL =================
void detectLeakAndControlValve() {
  if (!autoControlEnabled || !systemStabilized) return;
  
  // Check water sensors FIRST - if ANY sensor is WET (>= 25%), keep valve CLOSED
  // This check uses actual sensor readings, not the waterLeakDetected flag
  if (waterSensor1Percent >= 25.0 || waterSensor2Percent >= 25.0) {
    // At least one sensor is WET (25-100%) - keep valve closed (leak detected)
    if (valveOpen) {
      closeValve();
      if (waterSensor1Percent >= 25.0 && waterSensor2Percent >= 25.0) {
        Serial.println("🔒 Valve closed - BOTH sensors WET (25-100%), leak detected");
      } else if (waterSensor1Percent >= 25.0) {
        Serial.println("🔒 Valve closed - SENSOR 1 WET (25-100%), leak detected");
      } else {
        Serial.println("🔒 Valve closed - SENSOR 2 WET (25-100%), leak detected");
      }
    }
    return; // Don't process flow-based detection when water leak is active
  }
  
  // Both sensors are DRY (< 25%) - allow flow-based valve control
  // Valve can now open if flow is normal

  bool newLeakDetected = false;

  // Leak detection: flow between leakThreshold and startThreshold
  // Only detect if flow is above minimum threshold (ignore noise)
  if (flowRate > leakThreshold && flowRate < startThreshold && flowRate >= MIN_FLOW_THRESHOLD) {
    if (!leakDetected) {
      leakDetected = true;
      leakStartTime = millis();
      newLeakDetected = true;
      Serial.println("🚨 FLOW-BASED LEAK DETECTED!");
      
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
      Serial.println("✅ Flow leak resolved - Normal flow");
    }
    // Only open valve if ALL sensors are DRY (< 25%) - if ANY sensor is WET (>=25%), keep closed
    if (waterSensor1Percent < 25.0 && waterSensor2Percent < 25.0) {
      openValve();
    } else {
      // At least one sensor is WET (>=25%) - keep valve closed even with normal flow (leak detected)
      closeValve();
      if (waterSensor1Percent >= 25.0) {
        Serial.print("⚠️ Valve kept closed - Sensor 1 is WET (");
        Serial.print(waterSensor1Percent, 1);
        Serial.println("%)");
      }
      if (waterSensor2Percent >= 25.0) {
        Serial.print("⚠️ Valve kept closed - Sensor 2 is WET (");
        Serial.print(waterSensor2Percent, 1);
        Serial.println("%)");
      }
    }
    // Only turn off buzzer if NO water sensor leak is detected
    // Water sensor leak takes priority - keep buzzer ON if water leak is active
    if (!waterLeakDetected) {
      digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer only if no water leak
    }
  }
  // No flow: below leakThreshold
  else {
    if (leakDetected) {
      // Check if leak has been resolved (no flow for 10 seconds)
      if (millis() - leakStartTime > LEAK_ALERT_DURATION) {
        leakDetected = false;
        Serial.println("✅ Flow leak resolved - No flow");
      }
    }
    // Always close valve when there's no flow
    // BUT: if water sensors detect leak (>= 25%), valve MUST stay closed
    if (waterSensor1Percent >= 25.0 || waterSensor2Percent >= 25.0) {
      // Water sensor leak detected - keep valve closed
      closeValve();
      if (waterSensor1Percent >= 25.0 && waterSensor2Percent >= 25.0) {
        Serial.println("🔒 Valve closed - BOTH sensors WET (no flow + leak detected)");
      } else if (waterSensor1Percent >= 25.0) {
        Serial.println("🔒 Valve closed - SENSOR 1 WET (no flow + leak detected)");
      } else {
        Serial.println("🔒 Valve closed - SENSOR 2 WET (no flow + leak detected)");
      }
    } else {
      // No flow and sensors are dry - close valve normally
      closeValve();
    }
    // Only turn off buzzer if no water sensor leak
    if (!waterLeakDetected) {
      digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer
    }
  }
}
 
 // ================= VALVE CONTROL =================
 void openValve() {
   if (!valveOpen) {
     digitalWrite(VALVE_PIN, LOW); // LOW = open
     valveOpen = true;
     // Reset flow confirmation when valve opens (must wait for sustained flow)
     flowConfirmed = false;
     flowStartTime = 0;
     Serial.println("Valve OPENED - waiting for confirmed flow before counting");
     // Update LCD immediately when valve opens
     updateLCD();
   }
 }
 
 void closeValve() {
   if (valveOpen) {
     digitalWrite(VALVE_PIN, HIGH); // HIGH = closed
     valveOpen = false;
     // Reset flow confirmation when valve closes
     flowConfirmed = false;
     flowStartTime = 0;
     Serial.println("Valve CLOSED - flow counting stopped");
     // Update LCD immediately when valve closes
     updateLCD();
   }
 }
 
 // ================= LCD DISPLAY =================
 void updateLCD() {
   lcd.clear();
   
   if (!systemStabilized) {
     // Show stabilization message
     lcd.setCursor(0, 0);
     lcd.print("Initializing...");
     lcd.setCursor(0, 1);
     unsigned long elapsed = (millis() - systemStartTime) / 1000;
     lcd.print("Wait: ");
     lcd.print((STABILIZATION_PERIOD / 1000) - elapsed);
     lcd.print("s");
     return;
   }
   
  if (waterLeakDetected) {
    // Water sensor leak alert display - show which sensor detected
    // Make it very clear and prominent
    lcd.setCursor(0, 0);
    if (waterSensor1Detected && waterSensor2Detected) {
      lcd.print("!!! LEAK !!!   ");  // Both sensors
    } else if (waterSensor1Detected) {
      lcd.print("LEAK: SENSOR 1 ");  // Sensor 1 only
    } else if (waterSensor2Detected) {
      lcd.print("LEAK: SENSOR 2 ");  // Sensor 2 only
    } else {
      lcd.print("!!! LEAK !!!   ");  // Fallback
    }
    
    lcd.setCursor(0, 1);
    // Show sensor percentages
    lcd.print("S1:");
    if (waterSensor1Percent < 100) {
      lcd.print(waterSensor1Percent, 0);
    } else {
      lcd.print("100");
    }
    lcd.print("% S2:");
    if (waterSensor2Percent < 100) {
      lcd.print(waterSensor2Percent, 0);
    } else {
      lcd.print("100");
    }
    lcd.print("%");
  } else if (leakDetected) {
    // Flow-based leak alert display - show flow rate clearly
    lcd.setCursor(0, 0);
    lcd.print("FLOW LEAK!     ");
    lcd.setCursor(0, 1);
    lcd.print("Flow:");
    if (flowRate < 10) {
      lcd.print(flowRate, 2);
    } else {
      lcd.print(flowRate, 1);
    }
    lcd.print("L/m V:");
    lcd.print(valveOpen ? "OP" : "CL");
  } else {
     // Normal kitchen display
     // Line 1: Valve status and Flow rate
     lcd.setCursor(0, 0);
     if (valveOpen) {
       lcd.print("V:OPEN ");
     } else {
       lcd.print("V:CLOSED");
     }
     lcd.print(" F:");
     if (flowRate < 10) {
       lcd.print(flowRate, 1);
     } else {
       lcd.print(flowRate, 0);
     }
     lcd.print("L/m");
     
     // Line 2: Total water used and mode
     lcd.setCursor(0, 1);
     lcd.print("Total:");
     // Format total to fit (max 6 chars for total)
     if (totalUsed < 10) {
       lcd.print(totalUsed, 2);
     } else if (totalUsed < 100) {
       lcd.print(totalUsed, 1);
     } else if (totalUsed < 1000) {
       lcd.print(totalUsed, 0);
     } else {
       // For values >= 1000, show in kL
       lcd.print(totalUsed / 1000.0, 2);
       lcd.print("k");
     }
     lcd.print("L ");
     // Show mode indicator
     if (!autoControlEnabled) {
       lcd.print("MAN");  // Manual
     } else {
       lcd.print("AUTO");  // Auto
     }
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
   // Check WiFi connection
   if (WiFi.status() != WL_CONNECTED) {
     Serial.println("⚠️ WiFi not connected, cannot register device");
     return;
   }
 
   String url = String(supabaseUrl) + "/rest/v1/" + String(waterControlTable);
   
   Serial.print("🔵 Registering device... URL: ");
   Serial.println(url);
   
   http.begin(client, url);
   http.addHeader("Content-Type", "application/json");
   http.addHeader("apikey", supabaseKey);
   http.addHeader("Prefer", "return=representation");
   http.setConnectTimeout(10000);  // 10 second connection timeout
   http.setTimeout(10000);         // 10 second response timeout
 
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
   // Check WiFi connection before attempting update
   if (WiFi.status() != WL_CONNECTED) {
     Serial.println("⚠️ WiFi not connected, skipping Supabase update");
     return;
   }
 
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
 
   // Retry logic: try up to 3 times
   int maxRetries = 3;
   int httpCode = -1;
   bool success = false;
 
   for (int attempt = 1; attempt <= maxRetries; attempt++) {
     if (attempt > 1) {
       Serial.print("   Retry attempt ");
       Serial.print(attempt);
       Serial.print(" of ");
       Serial.println(maxRetries);
       delay(1000); // Wait 1 second before retry
     }
 
     http.begin(client, url);
     http.addHeader("Content-Type", "application/json");
     http.addHeader("apikey", supabaseKey);
     http.addHeader("Prefer", "return=representation");
     http.setConnectTimeout(10000);  // 10 second connection timeout
     http.setTimeout(10000);         // 10 second response timeout
 
     DynamicJsonDocument doc(1024);
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
     
     // Add water sensor readings to status update
     JsonObject sensorData = doc.createNestedObject("sensor_data");
     sensorData["water_sensor_1_value"] = waterSensor1Value;        // ADC value (0-4095)
     sensorData["water_sensor_1_percent"] = round(waterSensor1Percent * 10.0) / 10.0;  // Round to 1 decimal
     sensorData["water_sensor_1_detected"] = waterSensor1Detected; // true if >= 25%
     sensorData["water_sensor_2_value"] = waterSensor2Value;        // ADC value (0-4095)
     sensorData["water_sensor_2_percent"] = round(waterSensor2Percent * 10.0) / 10.0;  // Round to 1 decimal
     sensorData["water_sensor_2_detected"] = waterSensor2Detected; // true if >= 25%
     sensorData["water_leak_detected"] = waterLeakDetected;        // Overall leak status
     
     // last_heartbeat will use database default (now())
 
     String jsonString;
     serializeJson(doc, jsonString);
     
     if (attempt == 1) {
       Serial.print("   JSON: ");
       Serial.println(jsonString);
     }
 
     httpCode = http.PATCH(jsonString);
     
     if (attempt == 1 || httpCode > 0) {
       Serial.print("   HTTP Code: ");
       Serial.println(httpCode);
     }
     
     if (httpCode == 200 || httpCode == 204) {
       Serial.print("✅ Status updated successfully: Flow=");
       Serial.print(flowRate, 2);
       Serial.print(" L/min, Total=");
       Serial.print(totalUsed, 2);
       Serial.print(" L, Valve=");
       Serial.println(valveOpen ? "OPEN" : "CLOSED");
       success = true;
       http.end();
       break; // Success, exit retry loop
     } else if (httpCode > 0) {
       // Got a response but it's an error (not connection issue)
       Serial.print("❌ Update FAILED! HTTP code: ");
       Serial.println(httpCode);
       String response = http.getString();
       Serial.print("   Response: ");
       if (response.length() > 0) {
         Serial.println(response);
       } else {
         Serial.println("(empty response)");
       }
       http.end();
       break; // Don't retry on HTTP errors (4xx, 5xx)
     } else {
       // Connection error (httpCode < 0)
       Serial.print("   Connection error: ");
       Serial.println(http.errorToString(httpCode));
       http.end();
       // Will retry if attempts remaining
     }
   }
 
   if (!success && httpCode < 0) {
     Serial.print("❌ Update FAILED after ");
     Serial.print(maxRetries);
     Serial.println(" attempts - connection refused/timeout");
     Serial.print("   Error: ");
     Serial.println(http.errorToString(httpCode));
     Serial.println("   Check WiFi connection and Supabase URL");
   }
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
   // Only check for commands after system is stabilized
   // This prevents processing old commands from before device startup
   if (!systemStabilized) {
     return;
   }
 
   // Check WiFi connection
   if (WiFi.status() != WL_CONNECTED) {
     return; // Silently skip if WiFi is down
   }
 
   // Only fetch commands created after system startup (to avoid old commands)
   // Format: created_at=gte.2024-01-01T00:00:00Z (ISO 8601)
   // For simplicity, we'll just check pending commands and rely on status update
   String url = String(supabaseUrl) + "/rest/v1/" + String(commandsTable) +
                "?device_id=eq." + String(deviceId) +
                "&status=eq.pending" +
                "&order=created_at.asc" +
                "&limit=1";
 
   http.begin(client, url);
   http.addHeader("apikey", supabaseKey);
   http.setConnectTimeout(5000);  // 5 second connection timeout
   http.setTimeout(5000);          // 5 second response timeout
 
   int httpCode = http.GET();
 
   if (httpCode == 200) {
     String payload = http.getString();
 
     if (payload.length() > 2 && payload != "[]") {
       DynamicJsonDocument doc(1024);
       DeserializationError error = deserializeJson(doc, payload);
 
       if (!error && doc.is<JsonArray>() && doc.size() > 0) {
         JsonObject command = doc[0];
         String commandId = command["id"].as<String>();
         String commandType = command["command_type"].as<String>();
 
         Serial.print("📨 Received command: ");
         Serial.println(commandType);
 
         bool success = executeCommand(commandType);
 
         // Update command status immediately
         updateCommandStatus(commandId, success);
         
         // Update Supabase with new status
         updateDeviceStatus();
       }
     }
   } else if (httpCode != 404) {
     Serial.print("⚠️ Warning: Command check failed. HTTP code: ");
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
     // LCD already updated in openValve(), but ensure it's refreshed
     updateLCD();
   } else if (commandType == "close_valve") {
     autoControlEnabled = false;
     closeValve();
     success = true;
     Serial.println("Valve closed via command");
     // LCD already updated in closeValve(), but ensure it's refreshed
     updateLCD();
   } else if (commandType == "enable_auto") {
     autoControlEnabled = true;
     success = true;
     Serial.println("Auto control enabled");
     updateLCD(); // Update LCD to show auto mode
   } else if (commandType == "get_status") {
     updateDeviceStatus();
     success = true;
     updateLCD(); // Update LCD with current status
   } else {
     Serial.print("Unknown command: ");
     Serial.println(commandType);
   }
 
   return success;
 }
 
 void updateCommandStatus(String commandId, bool success) {
   // Check WiFi connection
   if (WiFi.status() != WL_CONNECTED) {
     return; // Silently skip if WiFi is down
   }
 
   String url = String(supabaseUrl) + "/rest/v1/" + String(commandsTable) + 
                "?id=eq." + commandId;
 
   http.begin(client, url);
   http.addHeader("Content-Type", "application/json");
   http.addHeader("apikey", supabaseKey);
   http.addHeader("Prefer", "return=representation");
   http.setConnectTimeout(5000);  // 5 second connection timeout
   http.setTimeout(5000);        // 5 second response timeout
 
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
   // Check WiFi connection
   if (WiFi.status() != WL_CONNECTED) {
     Serial.println("⚠️ WiFi not connected, cannot report leak");
     return;
   }
 
   String url = String(supabaseUrl) + "/rest/v1/" + String(leakDetectionsTable);
 
   http.begin(client, url);
   http.addHeader("Content-Type", "application/json");
   http.addHeader("apikey", supabaseKey);
   http.addHeader("Prefer", "return=representation");
   http.setConnectTimeout(10000);  // 10 second connection timeout
   http.setTimeout(10000);         // 10 second response timeout
 
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

void reportWaterLeakToSupabase() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi not connected, cannot report water leak");
    return;
  }

  String url = String(supabaseUrl) + "/rest/v1/" + String(leakDetectionsTable);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Prefer", "return=representation");
  http.setConnectTimeout(10000);  // 10 second connection timeout
  http.setTimeout(10000);         // 10 second response timeout

  DynamicJsonDocument doc(1024);
  doc["property_id"] = propertyId;
  doc["segment_id"] = segmentId;
  // detection_date will use database default (now())
  doc["leak_type"] = "water_sensor";
  doc["severity"] = waterSensor1Detected && waterSensor2Detected ? "high" : "medium";
  doc["status"] = "active";
  doc["location_description"] = "Kitchen - Water Sensor Detection";
  doc["estimated_water_loss_rate"] = 0.0; // Unknown for sensor detection
  doc["flow_rate_anomaly"] = flowRate;
  doc["confidence_score"] = 0.95; // High confidence for direct sensor detection

  JsonObject sensorData = doc.createNestedObject("sensor_data");
  sensorData["water_sensor_1_value"] = waterSensor1Value;
  sensorData["water_sensor_1_percent"] = waterSensor1Percent;
  sensorData["water_sensor_1_detected"] = waterSensor1Detected;
  sensorData["water_sensor_2_value"] = waterSensor2Value;
  sensorData["water_sensor_2_percent"] = waterSensor2Percent;
  sensorData["water_sensor_2_detected"] = waterSensor2Detected;
  sensorData["flow_rate_lpm"] = flowRate;
  sensorData["valve_status"] = valveOpen ? "open" : "closed";
  sensorData["buzzer_status"] = digitalRead(BUZZER_PIN) == HIGH ? "on" : "off";  // Include buzzer status
  sensorData["detection_method"] = "water_sensor";

  String jsonString;
  serializeJson(doc, jsonString);

  Serial.print("📤 Reporting water leak to Supabase: ");
  Serial.println(jsonString);

  int httpCode = http.POST(jsonString);

  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Water leak reported to Supabase");
  } else {
    Serial.print("❌ Failed to report water leak. HTTP code: ");
    Serial.println(httpCode);
    String response = http.getString();
    if (response.length() > 0) {
      Serial.print("Response: ");
      Serial.println(response);
    }
  }

  http.end();
}
