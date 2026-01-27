import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class ContactView extends StatefulWidget {
  @override
  _ContactViewState createState() => _ContactViewState();
}

class _ContactViewState extends State<ContactView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Database data
  Map<String, dynamic> developerInfo = {};
  List<Map<String, dynamic>> plumbingContacts = [];
  final SupabaseService _supabaseService = SupabaseService();
  bool isLoading = true;
  bool _initializedFromArgs = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _loadContactData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final contactsArg = args['contacts'];
      if (contactsArg is List) {
        final contacts = contactsArg
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _applyContacts(contacts);
        return;
      }
    }
  }

  void _applyContacts(List<Map<String, dynamic>> contacts) {
    bool isCatbaloganContact(Map<String, dynamic> contact) {
      final raw =
          (contact['address'] ?? contact['location'] ?? '').toString().toLowerCase();
      // If no address stored, keep it (assume local).
      if (raw.trim().isEmpty || raw == 'n/a') return true;
      return raw.contains('catbalogan');
    }

    plumbingContacts = contacts
        .where((contact) =>
            (contact['contact_type'] == 'plumber' ||
                contact['contact_type'] == 'emergency') &&
            isCatbaloganContact(contact))
        .map((contact) {
      return {
        'name': contact['name'] ?? 'Unknown',
        'phone': contact['phone'] ?? 'N/A',
        'email': contact['email'] ?? 'N/A',
        'rating': 4.5, // Default rating
        'specialty': contact['contact_type'] == 'plumber'
            ? 'Plumbing Services'
            : 'Emergency Services',
        'availability': '24/7',
        // Force the displayed location to Catbalogan only
        'location': 'Catbalogan City, Samar',
        'verified': contact['is_primary'] ?? false,
      };
    }).toList();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadContactData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Set developer info (you can customize this)
      developerInfo = {
        'name': 'WaterLeak Development Team',
        'email': 'support@waterleak.com',
        'phone': '+63 912 345 6789',
        'website': 'www.waterleak.com',
        'address': 'Catbalogan City, Samar, Philippines',
        'description':
            'Professional water leak detection and monitoring solutions.',
      };

      // Try to load emergency contacts from database
      try {
        // Load the same contacts managed in Admin (global list)
        final contacts = await _supabaseService.getAllEmergencyContacts(limit: 10000);
        _applyContacts(contacts);
      } catch (e) {
        print('Error loading contacts from database: $e');
        plumbingContacts = [];
      }

      // If no contacts found, keep empty list
      if (plumbingContacts.isEmpty) {
        plumbingContacts = [];
      }
    } catch (e) {
      print('Error loading contact data: $e');
      plumbingContacts = [];
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: Color(0xFF1e3c72),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(r),

            // Main Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: r.screenPadding(phone: 16, narrow: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(r.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Title
                        Container(
                          padding: r.screenPadding(phone: 16, narrow: 12),
                          decoration: BoxDecoration(
                            color: Color(0xFF1e3c72),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(r.cardRadius),
                              topRight: Radius.circular(r.cardRadius),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.contact_support,
                                color: Colors.white,
                                size: r.isSmallPhone ? 20 : 24,
                              ),
                              SizedBox(width: r.isSmallPhone ? 8 : 12),
                              Text(
                                'Contact Information',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.isSmallPhone ? 16 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: r.screenPadding(phone: 16, narrow: 12),
                            child: Column(
                              children: [
                                // Developer Information
                                _buildDeveloperSection(r),
                                SizedBox(height: r.isSmallPhone ? 20 : 24),

                                // Emergency Contacts
                                _buildEmergencySection(r),
                                SizedBox(height: r.isSmallPhone ? 20 : 24),

                                // Plumbing Contacts
                                _buildPlumbingSection(r),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return Container(
      padding: r.screenPadding(phone: 16, narrow: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Contact & Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.isSmallPhone ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.isSmallPhone ? 8 : 12,
              vertical: r.isSmallPhone ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: r.isSmallPhone ? 14 : 16,
                ),
                SizedBox(width: r.isSmallPhone ? 2 : 4),
                Text(
                  '24/7',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.isSmallPhone ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection(Responsive r) {
    return Container(
      padding: r.screenPadding(phone: 16, narrow: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1e3c72),
            Color(0xFF2193b0),
          ],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.developer_mode,
                color: Colors.white,
                size: r.isSmallPhone ? 20 : 24,
              ),
              SizedBox(width: r.isSmallPhone ? 6 : 8),
              Text(
                'Developer Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.isSmallPhone ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: r.isSmallPhone ? 12 : 16),
          Text(
            developerInfo['description'],
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: r.isSmallPhone ? 12 : 14,
            ),
          ),
          SizedBox(height: r.isSmallPhone ? 12 : 16),
          _buildContactItem(Icons.email, 'Email', developerInfo['email'],
              () => _launchEmail(developerInfo['email'])),
          _buildContactItem(Icons.phone, 'Phone', developerInfo['phone'],
              () => _launchPhone(developerInfo['phone'])),
          _buildContactItem(Icons.language, 'Website', developerInfo['website'],
              () => _launchWebsite(developerInfo['website'])),
          _buildContactItem(
              Icons.location_on, 'Address', developerInfo['address'], null),
        ],
      ),
    );
  }

  Widget _buildEmergencySection(Responsive r) {
    return Container(
      padding: r.screenPadding(phone: 16, narrow: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red[400]!,
            Colors.red[600]!,
          ],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Emergency Contacts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildContactItem(Icons.local_police, 'Emergency Services', '911',
              () => _launchPhone('911')),
          _buildContactItem(
              Icons.build,
              'Emergency Repairman - Catbalogan',
              'Juan Dela Cruz - +63 912 345 6789',
              () => _launchPhone('+639123456789')),
          _buildContactItem(Icons.water_drop, 'Catbalogan Water District',
              '+63 55 251 2345', () => _launchPhone('+63552512345')),
          _buildContactItem(
              Icons.engineering,
              'App Developer Support - Catbalogan',
              'Tech Solutions Inc. - +63 917 123 4567',
              () => _launchPhone('+639171234567')),
        ],
      ),
    );
  }

  Widget _buildPlumbingSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.plumbing,
              color: Color(0xFF1e3c72),
              size: r.isSmallPhone ? 20 : 24,
            ),
            SizedBox(width: r.isSmallPhone ? 6 : 8),
            Text(
              'Recommended Plumbers',
              style: TextStyle(
                color: Color(0xFF1e3c72),
                fontSize: r.isSmallPhone ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: r.isSmallPhone ? 12 : 16),
        ...plumbingContacts.map((contact) => _buildPlumberCard(contact, r)),
      ],
    );
  }

  Widget _buildContactItem(
      IconData icon, String label, String value, VoidCallback? onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: Icon(Icons.call, color: Colors.white, size: 20),
              onPressed: onTap,
            ),
        ],
      ),
    );
  }

  Widget _buildPlumberCard(Map<String, dynamic> contact, Responsive r) {
    return Container(
      margin: EdgeInsets.only(bottom: r.isSmallPhone ? 8 : 12),
      padding: r.screenPadding(phone: 16, narrow: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: contact['verified'] ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          contact['name'],
                          style: TextStyle(
                            fontSize: r.isSmallPhone ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (contact['verified'])
                          Container(
                            margin:
                                EdgeInsets.only(left: r.isSmallPhone ? 4 : 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.isSmallPhone ? 4 : 6,
                                vertical: r.isSmallPhone ? 1 : 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(r.cardRadius),
                            ),
                            child: Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.isSmallPhone ? 8 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '${contact['rating']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          contact['specialty'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPlumberInfo(Icons.phone, contact['phone'],
                    () => _launchPhone(contact['phone'])),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildPlumberInfo(Icons.email, contact['email'],
                    () => _launchEmail(contact['email'])),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPlumberInfo(
                    Icons.access_time, contact['availability'], null),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildPlumberInfo(
                    Icons.location_on, contact['location'], null),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchPhone(contact['phone']),
                  icon: Icon(Icons.phone, size: 16),
                  label: Text('Call Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1e3c72),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchEmail(contact['email']),
                  icon: Icon(Icons.email, size: 16),
                  label: Text('Email'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF1e3c72),
                    side: BorderSide(color: Color(0xFF1e3c72)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlumberInfo(IconData icon, String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchPhone(String phone) {
    // In a real app, this would launch the phone dialer
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call $phone?'),
        content: Text('This would launch the phone dialer in a real app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Call'),
          ),
        ],
      ),
    );
  }

  void _launchEmail(String email) {
    // In a real app, this would launch the email client
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Email $email?'),
        content: Text('This would launch the email client in a real app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Email'),
          ),
        ],
      ),
    );
  }

  void _launchWebsite(String website) {
    // In a real app, this would launch the website
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Visit $website?'),
        content: Text('This would launch the website in a real app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Visit'),
          ),
        ],
      ),
    );
  }
}
