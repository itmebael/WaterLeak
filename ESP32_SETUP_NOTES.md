# ESP32 Setup Notes for Water Leak Detection

## ESP32 Specific Configuration

### Pin Connections

```
Component              ESP32 Pin
-------------------    ---------
Flow Sensor Signal     GPIO 4
Pressure Sensor        GPIO 34 (ADC1_CH6) or GPIO 35 (ADC1_CH7)
Relay (Valve Control)   GPIO 5
Status LED             GPIO 2 (built-in LED on most boards)
Buzzer                 GPIO 14 (optional)
LCD SDA                GPIO 21 (default I2C)
LCD SCL                GPIO 22 (default I2C)
```

### Important ESP32 Notes

1. **ADC Pins**: 
   - Use GPIO 34, 35, 36, or 39 for analog input (ADC1)
   - These pins are input-only (no pull-up/pull-down)
   - ADC resolution: 12-bit (0-4095), 0-3.3V

2. **I2C Pins**:
   - Default: SDA = GPIO 21, SCL = GPIO 22
   - Can be changed in code if needed

3. **Interrupts**:
   - All GPIO pins can be used for interrupts
   - Use `attachInterrupt()` with `digitalPinToInterrupt()`

4. **WiFi**:
   - ESP32 supports both 2.4GHz and 5GHz WiFi
   - Better range and stability than ESP8266

### Libraries Required

Install these in Arduino IDE:

1. **ESP32 Board Support**:
   - File → Preferences → Additional Board Manager URLs
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Tools → Board → Boards Manager → Search "ESP32" → Install

2. **Required Libraries**:
   - WiFi (included with ESP32)
   - HTTPClient (included with ESP32)
   - ArduinoJson (v6.x) - Install from Library Manager
   - LiquidCrystal_I2C - Install from Library Manager

### Board Selection

In Arduino IDE:
- **Tools → Board → ESP32 Arduino → ESP32 Dev Module**

### Upload Settings

- **Upload Speed**: 115200 (or 921600 for faster uploads)
- **CPU Frequency**: 240MHz (default)
- **Flash Frequency**: 80MHz
- **Flash Size**: 4MB (or match your board)
- **Partition Scheme**: Default 4MB with spiffs

### Serial Monitor

- **Baud Rate**: 115200
- **Line Ending**: Both NL & CR

### Common Issues

1. **Upload Failed**:
   - Hold BOOT button while uploading
   - Try different USB cable
   - Lower upload speed to 115200

2. **WiFi Not Connecting**:
   - Check 2.4GHz WiFi (ESP32 doesn't support 5GHz in station mode)
   - Verify SSID and password
   - Check signal strength

3. **ADC Reading Issues**:
   - Use GPIO 34, 35, 36, or 39 for analog input
   - These pins are input-only
   - Voltage range: 0-3.3V

4. **LCD Not Displaying**:
   - Check I2C address (use I2C scanner)
   - Verify SDA/SCL connections (GPIO 21/22)
   - Check power supply (3.3V or 5V depending on LCD)

### Power Supply

- **USB**: 5V, 500mA minimum
- **External**: 5V regulated, 1A recommended
- **Battery**: 3.7V LiPo with voltage regulator

### Performance Tips

1. **WiFi Power Management**:
   - ESP32 has better power management than ESP8266
   - Can use light sleep mode between readings

2. **ADC Accuracy**:
   - ESP32 ADC has non-linear characteristics
   - Consider calibration for precise readings
   - Use external ADC (ADS1115) for better accuracy if needed

3. **Interrupt Handling**:
   - ESP32 handles interrupts efficiently
   - Flow sensor interrupt works reliably

### Testing

1. **Test Flow Sensor**:
   - Blow air through sensor or run water
   - Check Serial Monitor for pulse count
   - Verify flow rate calculation

2. **Test Pressure Sensor**:
   - Read analog value in Serial Monitor
   - Verify voltage calculation
   - Check PSI conversion

3. **Test LCD**:
   - Upload I2C scanner sketch first
   - Find LCD address
   - Update address in main code

4. **Test WiFi**:
   - Check Serial Monitor for connection status
   - Verify IP address assignment
   - Test Supabase connection

### Code Differences from ESP8266

1. **Libraries**:
   - `WiFi.h` instead of `ESP8266WiFi.h`
   - `HTTPClient.h` instead of `ESP8266HTTPClient.h`

2. **ADC**:
   - 12-bit (0-4095) instead of 10-bit (0-1023)
   - 0-3.3V range (no voltage divider needed)

3. **I2C**:
   - Default pins: GPIO 21 (SDA), GPIO 22 (SCL)
   - Can be changed with `Wire.begin(SDA, SCL)`

4. **Interrupts**:
   - Same API, but better performance
   - Use `IRAM_ATTR` for interrupt handlers

### Additional Features (ESP32 Advantages)

1. **Dual Core**: Can use second core for non-critical tasks
2. **Bluetooth**: Can add BLE for local communication
3. **More GPIO**: More pins available for expansion
4. **Better WiFi**: Improved range and stability



