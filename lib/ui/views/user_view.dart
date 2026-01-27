import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:waterleak/core/services/auth_service.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserView extends StatefulWidget {
  @override
  _UserViewState createState() => _UserViewState();
}

class _UserViewState extends State<UserView> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;
  late Animation<Offset> _slideAnimation;

  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _contentAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
    _loadProfile();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('profile_image_path');
      if (imagePath != null && File(imagePath).existsSync()) {
        setState(() {
          _profileImage = File(imagePath);
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', image.path);
        setState(() {
          _profileImage = imageFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _contentController.forward();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _loadingProfile = true;
      });
      final current = _authService.currentUser;
      if (current == null || current['id'] == null) {
        setState(() {
          _loadingProfile = false;
        });
        return;
      }
      final profile = await _authService.getUserProfile(current['id']);
      setState(() {
        _profile = profile ??
            {
              'id': current['id'],
              'email': current['email'],
              'full_name': current['full_name'],
              'phone_number': current['phone'],
            };
        _loadingProfile = false;
      });
    } catch (_) {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  void _showEditProfileDialog() {
    final nameController =
        TextEditingController(text: (_profile?['full_name'] ?? '').toString());
    final phoneController = TextEditingController(
        text: (_profile?['phone_number'] ?? '').toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Profile',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = _profile?['id']?.toString();
                if (id != null) {
                  await _authService.updateProfile(
                    userId: id,
                    fullName: nameController.text.trim().isEmpty
                        ? null
                        : nameController.text.trim(),
                    phone: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  );
                  await _loadProfile();
                }
                if (mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
                foregroundColor: Colors.white,
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFieldDialog(String label, String currentValue, String fieldKey) {
    final controller = TextEditingController(text: currentValue == '—' ? '' : currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit $label',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            enabled: fieldKey != 'email', // Email is usually not editable
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = _profile?['id']?.toString();
                if (id == null) {
                  Navigator.of(context).pop();
                  return;
                }

                final newValue = controller.text.trim();
                if (fieldKey == 'email' && newValue.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Email cannot be empty')),
                  );
                  return;
                }

                try {
                  if (fieldKey == 'full_name') {
                    await _authService.updateProfile(
                      userId: id,
                      fullName: newValue.isEmpty ? null : newValue,
                    );
                  } else if (fieldKey == 'phone') {
                    await _authService.updateProfile(
                      userId: id,
                      phone: newValue.isEmpty ? null : newValue,
                    );
                  }
                  await _loadProfile();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
                foregroundColor: Colors.white,
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1e3c72),
                      Color(0xFF2193b0),
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(20, (index) => _buildFloatingParticle(index)),

          // Modern AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentAnimation,
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Manage your account',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.white, size: 20),
                        onPressed: _loadingProfile || _profile == null
                            ? null
                            : _showEditProfileDialog,
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _contentAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final r = Responsive(context);
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.horizontalPadding(
                            phone: 12, narrow: 10, veryNarrow: 8),
                      ),
                      child: Column(
                        children: [
                          // Profile header
                          _buildProfileHeader(),
                          SizedBox(height: r.mediumSpacing),

                          // User info section (editable)
                          _buildUserInfoSection(),
                          SizedBox(height: r.mediumSpacing),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingParticle(int index) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final r = Responsive(context);
        return Positioned(
          left: (index * 47) % r.w,
          top: (index * 83) % r.h,
          child: Opacity(
            opacity: 0.2,
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  children: [
                    Container(
                      width: r.isSmallPhone ? 80 : 100,
                      height: r.isSmallPhone ? 80 : 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.white.withValues(alpha: 0.9)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _profileImage != null
                          ? ClipOval(
                              child: Image.file(
                                _profileImage!,
                                width: r.isSmallPhone ? 80 : 100,
                                height: r.isSmallPhone ? 80 : 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: r.isSmallPhone ? 40 : 50,
                              color: Color(0xFF1e3c72),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: r.isSmallPhone ? 28 : 32,
                        height: r.isSmallPhone ? 28 : 32,
                        decoration: BoxDecoration(
                          color: Color(0xFF1e3c72),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: r.isSmallPhone ? 16 : 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.mediumSpacing),
              Text(
                (_profile?['full_name'] ?? 'Your Name').toString(),
                style: TextStyle(
                  fontSize: r.isSmallPhone ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: r.smallSpacing),
              Text(
                (_profile?['email'] ?? '').toString(),
                style: TextStyle(
                  fontSize: r.isSmallPhone ? 14 : 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserInfoSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: _showEditProfileDialog,
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
              SizedBox(height: r.mediumSpacing),
              _buildEditableInfoItem(Icons.person, 'Full Name',
                  (_profile?['full_name'] ?? '—').toString(), 'full_name', r),
              _buildEditableInfoItem(Icons.email, 'Email',
                  (_profile?['email'] ?? '—').toString(), 'email', r),
              _buildEditableInfoItem(Icons.phone, 'Phone',
                  (_profile?['phone_number'] ?? '—').toString(), 'phone', r),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditableInfoItem(
      IconData icon, String label, String value, String fieldKey, Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.smallSpacing),
      child: InkWell(
        onTap: () => _showEditFieldDialog(label, value, fieldKey),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(r.smallSpacing),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(r.cardRadius),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: r.isSmallPhone ? 16 : 20,
              ),
            ),
            SizedBox(width: r.mediumSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 12 : 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.isSmallPhone ? 1 : 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              color: Colors.white.withValues(alpha: 0.6),
              size: r.isSmallPhone ? 16 : 18,
            ),
          ],
        ),
      ),
    );
  }
}

