# Android Login/Signup Troubleshooting Guide

## ✅ Issues Fixed:

1. **INTERNET Permission Added** - Android now has permission to access network
2. **Network Security Config Created** - Proper HTTPS configuration for Supabase connection
3. **Manifest Updated** - References the network security configuration

## 🚀 Steps to Test:

### 1. **Rebuild Your Android App**
```bash
flutter clean
flutter pub get
flutter run -d android
```

### 2. **Verify Network Connectivity**
- Ensure your device/emulator has internet access
- Check that WiFi or mobile data is enabled
- Try to open a website in Chrome to confirm connectivity

### 3. **Check Supabase Credentials**
The app uses:
- **URL**: `https://pcddnhsvxjnwwmwchujk.supabase.co`
- **Key**: `sb_publishable_FUK89NzP96SBBnOsgbIeZg_yX0Conps`

✅ Verify these are correct in `lib/core/config/supabase_config.dart`

### 4. **Test Admin Login First**
Try logging in with these credentials:
- **Email**: `admin@waterleak.com`
- **Password**: `admin123`

This uses hardcoded auth (no database required) and will confirm the UI is working.

### 5. **Monitor Console Logs**
When testing signup/login, watch the Flutter console for:
```
🔄 Attempting to register user: ...
📤 Supabase response: ...
✅ User registered successfully
❌ Registration failed: ...
```

## 🔍 Common Issues & Solutions:

| Issue | Solution |
|-------|----------|
| "Network connection failed" | Check internet connection on device |
| "HandshakeException" | HTTPS certificate issue - check network_security_config.xml |
| "register_user function not found" | Run the SQL setup script in Supabase |
| "Invalid email or password" | Verify user exists in database with correct credentials |
| "SocketException" | Device cannot reach Supabase - check firewall/VPN |

## 📱 For Android Emulator:

If using Android emulator, check:
1. Emulator has internet access: Settings > WiFi > should show connection
2. Firewall allows localhost traffic: May need to adjust firewall rules
3. Supabase URL is accessible: Try pinging from emulator terminal

## 🛠️ Database Verification:

In Supabase SQL Editor, verify:
```sql
-- Check if register_user function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'register_user';

-- Check if users table is accessible
SELECT COUNT(*) FROM public.users;

-- Check recent user registrations
SELECT id, email, created_at FROM public.users ORDER BY created_at DESC LIMIT 5;
```

## 🔐 Debug Authentication Flow:

1. When signup fails, check the error in the SnackBar
2. Enable verbose logging by adding this to `main.dart`:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     // Enable detailed logging
     Logger.root.level = Level.ALL;
     Logger.root.onRecord.listen((record) {
       print('${record.level.name}: ${record.time}: ${record.message}');
     });
     
     await AuthService().initialize();
     runApp(MyApp());
   }
   ```

## ✨ Next Steps After Fix:

1. Rebuild the app with the fixes
2. Test admin login (should work immediately)
3. Test regular signup
4. If still failing, check console logs and compare with the Database Verification queries above
5. Verify the `register_user` and `login_user` functions exist in your Supabase database

---

If you're still having issues after these fixes, check:
- Device internet connection is working
- Supabase URL is accessible (check Supabase dashboard status)
- Database functions were properly created (run the SQL setup)
