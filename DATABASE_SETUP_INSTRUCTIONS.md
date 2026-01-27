# Database Setup Instructions

## Quick Fix for Database Issues

The errors you're seeing are because the database tables don't exist yet. Here's how to fix them:

### Option 1: Run the Database Setup Script (Recommended)

1. **Open your Supabase Dashboard**
   - Go to [supabase.com](https://supabase.com)
   - Sign in to your account
   - Open your project

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Run the Setup Script**
   - Copy the entire contents of `setup_database.sql` file
   - Paste it into the SQL editor
   - Click "Run" to execute the script

4. **Verify Tables Created**
   - Go to "Table Editor" in the left sidebar
   - You should see all the tables listed:
     - users
     - properties
     - pipeline_segments
     - water_consumption_daily
     - water_consumption_weekly
     - water_consumption_monthly
     - water_leak_detections
     - leak_notifications
     - leak_history
     - sensor_readings
     - water_switch_controls
     - emergency_contacts
     - system_settings
     - water_savings_targets
     - maintenance_schedules
     - kitchen_valve_control
     - water_data

### Option 2: Manual Table Creation

If the script doesn't work, you can create the tables manually:

1. **Create the main tables first:**
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

   CREATE TABLE properties (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       user_id UUID REFERENCES users(id) ON DELETE CASCADE,
       property_name VARCHAR(255) NOT NULL,
       property_type VARCHAR(100) NOT NULL,
       address TEXT NOT NULL,
       city VARCHAR(100) NOT NULL,
       state VARCHAR(100) NOT NULL,
       zip_code VARCHAR(20) NOT NULL,
       total_area DECIMAL(10,2),
       number_of_floors INTEGER DEFAULT 1,
       year_built INTEGER,
       is_active BOOLEAN DEFAULT true,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

2. **Create the kitchen_valve_control table:**
   ```sql
   CREATE TABLE kitchen_valve_control (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       valve_status VARCHAR(50) NOT NULL DEFAULT 'closed',
       last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       updated_by VARCHAR(255),
       notes TEXT,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

3. **Create the water_data table:**
   ```sql
   CREATE TABLE water_data (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       flow_rate DECIMAL(5,2),
       pressure DECIMAL(5,2),
       temperature DECIMAL(4,2),
       timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       sensor_id VARCHAR(100),
       location VARCHAR(255),
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

### Option 3: Reset and Recreate (If you have existing data issues)

1. **Backup your data** (if any)
2. **Drop all tables** in the SQL editor:
   ```sql
   DROP TABLE IF EXISTS water_data CASCADE;
   DROP TABLE IF EXISTS kitchen_valve_control CASCADE;
   DROP TABLE IF EXISTS maintenance_schedules CASCADE;
   DROP TABLE IF EXISTS water_savings_targets CASCADE;
   DROP TABLE IF EXISTS system_settings CASCADE;
   DROP TABLE IF EXISTS emergency_contacts CASCADE;
   DROP TABLE IF EXISTS water_switch_controls CASCADE;
   DROP TABLE IF EXISTS sensor_readings CASCADE;
   DROP TABLE IF EXISTS leak_history CASCADE;
   DROP TABLE IF EXISTS leak_notifications CASCADE;
   DROP TABLE IF EXISTS water_leak_detections CASCADE;
   DROP TABLE IF EXISTS water_consumption_monthly CASCADE;
   DROP TABLE IF EXISTS water_consumption_weekly CASCADE;
   DROP TABLE IF EXISTS water_consumption_daily CASCADE;
   DROP TABLE IF EXISTS pipeline_segments CASCADE;
   DROP TABLE IF EXISTS properties CASCADE;
   DROP TABLE IF EXISTS users CASCADE;
   ```
3. **Run the setup script** from Option 1

## After Database Setup

1. **Restart your Flutter app**
2. **Login with your credentials**
3. **The app will automatically create sample data** for testing

## Troubleshooting

### If you still get "table not found" errors:
- Make sure you're running the SQL in the correct Supabase project
- Check that the tables were created successfully in the Table Editor
- Verify your Supabase connection settings in `lib/core/config/supabase_config.dart`

### If you get permission errors:
- Make sure Row Level Security (RLS) is properly configured
- Check that your Supabase API keys are correct
- Verify that the user has proper permissions

### If the app still shows "not authenticated":
- Make sure you're logged in
- Check that the authentication flow is working
- Verify that the user session is valid

## Sample Data

The app will automatically create sample data including:
- A default property in Catbalogan
- Sample pipeline segments (Kitchen, Bathroom)
- 30 days of water consumption data
- Sample leak detection data
- Emergency contacts for Catbalogan

This will allow you to test all the features immediately after setup.

## Support

If you continue to have issues:
1. Check the Flutter console for detailed error messages
2. Verify your Supabase project settings
3. Make sure all required tables exist
4. Check that your API keys are correct

The app should work perfectly once the database is properly set up!

