# Water Leak Detection System - Database Setup Guide

## Overview
This document provides complete instructions for setting up the Supabase database for the Water Leak Detection System. The database includes 15 tables covering all aspects of water monitoring, leak detection, user management, and system configuration.

## Database Tables Summary

### 1. Core User Management
- **users** - User accounts and profiles
- **properties** - Properties managed by users
- **pipeline_segments** - Individual pipeline sections for monitoring

### 2. Water Consumption Tracking
- **water_consumption_daily** - Daily water usage data
- **water_consumption_weekly** - Weekly aggregated consumption
- **water_consumption_monthly** - Monthly aggregated consumption

### 3. Leak Detection & Management
- **water_leak_detections** - Detected water leaks
- **leak_notifications** - User notifications for leaks
- **leak_history** - History of actions taken on leaks

### 4. Sensor & Control Systems
- **sensor_readings** - Real-time sensor data
- **water_switch_controls** - Water flow control switches

### 5. Support & Configuration
- **emergency_contacts** - Emergency contact information
- **system_settings** - Application configuration
- **water_savings_targets** - Water conservation goals
- **maintenance_schedules** - Scheduled maintenance tasks

## Setup Instructions

### Step 1: Supabase Project Setup
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project or use existing project
3. Note your project URL and anon key

### Step 2: Database Schema Setup
1. Open your Supabase project dashboard
2. Go to SQL Editor
3. Copy and paste the entire contents of `database_schema.sql`
4. Execute the SQL script

### Step 3: Flutter App Configuration
1. Update `lib/core/config/supabase_config.dart` with your credentials:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'YOUR_PROJECT_URL';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

### Step 4: Install Dependencies
Run the following command to install Supabase dependencies:
```bash
flutter pub get
```

## Database Schema Details

### Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'Philippines',
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Water Consumption Tables
The system tracks water consumption at three levels:

1. **Daily Consumption** - Hourly and daily usage patterns
2. **Weekly Consumption** - Aggregated weekly data for trends
3. **Monthly Consumption** - Monthly summaries with savings calculations

### Leak Detection System
- Real-time leak detection with severity levels
- Automatic notification system
- Historical tracking of all leak events
- Resolution tracking and cost management

### Sensor Integration
- Pressure monitoring (PSI)
- Flow rate tracking (LPM)
- Temperature and humidity monitoring
- Vibration detection for pipe integrity

## Key Features

### 1. Real-time Monitoring
- Live sensor data streaming
- Instant leak detection alerts
- Real-time water flow monitoring

### 2. Smart Notifications
- Multi-channel notifications (email, SMS, push, in-app)
- Configurable notification preferences
- Severity-based alerting

### 3. Water Conservation
- Usage pattern analysis
- Anomaly detection
- Savings targets and tracking
- Cost calculation in PHP

### 4. Maintenance Management
- Scheduled maintenance tracking
- Inspection reminders
- Repair history logging
- Cost tracking

### 5. Emergency Response
- Emergency contact management
- Quick access to plumbers
- Automatic shutoff controls
- Emergency protocols

## API Endpoints (via SupabaseService)

### User Management
```dart
// Sign up new user
await supabaseService.signUp(email: 'user@example.com', password: 'password', firstName: 'John', lastName: 'Doe');

// Sign in
await supabaseService.signIn(email: 'user@example.com', password: 'password');

// Sign out
await supabaseService.signOut();
```

### Property Management
```dart
// Get user properties
List<Map<String, dynamic>> properties = await supabaseService.getProperties();

// Create new property
Map<String, dynamic> property = await supabaseService.createProperty({
  'property_name': 'My Home',
  'property_type': 'residential',
  'address': '123 Main St',
  'city': 'Manila',
  'state': 'NCR',
  'zip_code': '1000'
});
```

### Water Consumption
```dart
// Get daily consumption
List<Map<String, dynamic>> dailyData = await supabaseService.getDailyConsumption(propertyId);

// Get weekly consumption
List<Map<String, dynamic>> weeklyData = await supabaseService.getWeeklyConsumption(propertyId);

// Get monthly consumption
List<Map<String, dynamic>> monthlyData = await supabaseService.getMonthlyConsumption(propertyId);
```

### Leak Detection
```dart
// Get active leaks
List<Map<String, dynamic>> activeLeaks = await supabaseService.getLeakDetections(propertyId, status: 'active');

// Create leak detection
Map<String, dynamic> leak = await supabaseService.createLeakDetection({
  'property_id': propertyId,
  'segment_id': segmentId,
  'leak_type': 'continuous',
  'severity': 'high',
  'location_description': 'Kitchen sink area'
});
```

### Real-time Subscriptions
```dart
// Subscribe to leak detections
Stream<List<Map<String, dynamic>>> leakStream = supabaseService.subscribeToLeakDetections(propertyId);

// Subscribe to sensor readings
Stream<List<Map<String, dynamic>>> sensorStream = supabaseService.subscribeToSensorReadings(segmentId);

// Subscribe to notifications
Stream<List<Map<String, dynamic>>> notificationStream = supabaseService.subscribeToNotifications();
```

## Data Flow

### 1. Sensor Data Collection
```
Sensors → sensor_readings table → Real-time processing → Anomaly detection
```

### 2. Leak Detection Process
```
Anomaly detected → water_leak_detections table → Notification system → User alerts
```

### 3. Consumption Tracking
```
Daily usage → water_consumption_daily → Weekly aggregation → Monthly summaries
```

### 4. User Interaction
```
User actions → Database updates → Real-time UI updates → Historical tracking
```

## Security Features

### Row Level Security (RLS)
- User data isolation
- Property-based access control
- Secure API endpoints

### Authentication
- Supabase Auth integration
- Secure password handling
- Session management

### Data Validation
- Input validation at database level
- Type checking and constraints
- Referential integrity

## Performance Optimization

### Indexes
- Optimized queries for common operations
- Fast lookups for user data
- Efficient date-based queries

### Real-time Features
- WebSocket connections for live updates
- Efficient streaming for sensor data
- Minimal latency for notifications

## Monitoring & Maintenance

### Database Health
- Regular backup schedules
- Performance monitoring
- Query optimization

### System Alerts
- Database connection monitoring
- Error tracking and logging
- Performance metrics

## Troubleshooting

### Common Issues
1. **Connection Errors** - Check Supabase URL and API key
2. **Permission Errors** - Verify RLS policies
3. **Real-time Issues** - Check WebSocket connections
4. **Data Sync Issues** - Verify table structure matches schema

### Support
- Check Supabase documentation
- Review error logs
- Test with sample data
- Verify network connectivity

## Next Steps

1. **Deploy Schema** - Execute the SQL script in your Supabase project
2. **Configure App** - Update the config file with your credentials
3. **Test Integration** - Verify all database operations work correctly
4. **Add Sample Data** - Populate with test data for development
5. **Monitor Performance** - Set up monitoring and alerts

## Sample Data Insertion

After setting up the schema, you can insert sample data for testing:

```sql
-- Insert sample user
INSERT INTO users (email, password_hash, first_name, last_name, phone) 
VALUES ('test@example.com', 'hashed_password', 'Test', 'User', '+639123456789');

-- Insert sample property
INSERT INTO properties (user_id, property_name, property_type, address, city, state, zip_code)
VALUES ('user_uuid', 'Test Property', 'residential', '123 Test St', 'Manila', 'NCR', '1000');
```

This database structure provides a comprehensive foundation for your water leak detection system with all the features you requested including water consumption tracking (daily, weekly, monthly), leak notifications, user data management, and more.
