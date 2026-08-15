import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_util.dart';
import '../utils/app_theme.dart';
import 'role_selection_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SchoolSelectionScreenState createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _schoolIdController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _schools = [];
  String _currentTheme = AppTheme.defaultTheme;
  bool _isLoadingSchools = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    
    // Wrap initialization in microtask to avoid blocking the UI
    Future.microtask(() async {
      // First ensure StorageUtil is initialized
      await StorageUtil.init();
      // Then load persistent data
      await _loadTheme();
      // Check if we have existing credentials
      await _checkForExistingSchool();
      // Finally load schools from API (can fail without breaking the app)
      await _loadSchools();
      await _checkSharedPreferencesStatus(showErrorDialog: false);
    });
  }

  // Modified method to debug SharedPreferences with optional dialog display
  Future<void> _checkSharedPreferencesStatus({bool showErrorDialog = false}) async {
    try {
      // Test if SharedPreferences is working
      final prefs = await SharedPreferences.getInstance();
      final testKey = 'shared_prefs_test_key';
      final testValue = 'test_value_${DateTime.now().millisecondsSinceEpoch}';
      
      // Try to write a value
      await prefs.setString(testKey, testValue);
      
      // Try to read it back
      final readValue = prefs.getString(testKey);
      
      print('🔍 SharedPreferences working: ${testValue == readValue}');
      
      if (testValue != readValue && showErrorDialog) {
        print('⚠️ WARNING: SharedPreferences write/read test failed!');
        _showSharedPreferencesErrorDialog();
      }
      
      // Check path and storage details
      print('🔍 SharedPreferences directory info:');
      print('🔍 App directory: ${await _getAppDirectory()}');
    } catch (e) {
      print('⚠️ ERROR accessing SharedPreferences: $e');
      if (showErrorDialog) _showSharedPreferencesErrorDialog();
    }
  }
  
  // Helper to get app directory for debugging
  Future<String> _getAppDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // This is just a trick to get some path info
      final keys = prefs.getKeys();
      return 'Available keys: ${keys.join(', ')}';
    } catch (e) {
      return 'Unable to get directory info: $e';
    }
  }
  
  // Show an error dialog if SharedPreferences fails
  void _showSharedPreferencesErrorDialog() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Storage Error'),
            content: const Text(
              'There seems to be an issue with app storage. Your data may not be saved between sessions. '
              'This could be due to limited storage permissions or device storage issues.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _loadTheme() async {
    final theme = await StorageUtil.getString('appTheme') ?? AppTheme.defaultTheme;
    setState(() {
      _currentTheme = theme;
    });
  }

  @override
  void dispose() {
    _schoolIdController.dispose();
    super.dispose();
  }

  // Check if a school token already exists and navigate if it does
  Future<void> _checkForExistingSchool() async {
    try {
      print('🏫 Checking for existing school credentials...');
      // Get all required school data
      final String? schoolToken = await StorageUtil.getString('schoolToken');
      final String? schoolName = await StorageUtil.getString('schoolName');
      final String? schoolAddress = await StorageUtil.getString('schoolAddress');
      final String? schoolPhone = await StorageUtil.getString('schoolPhone');
      final bool? isLoggedIn = await StorageUtil.getBool('isLoggedIn');
      
      print('🏫 School check results: Token: ${schoolToken != null ? "Found" : "Not found"}, '
          'Name: ${schoolName ?? "Not found"}, '
          'IsLoggedIn: ${isLoggedIn == true ? "Yes" : "No"}');
      
      // Only navigate if we have all required data AND the user is logged in
      if (schoolToken != null && schoolToken.isNotEmpty && 
          schoolName != null && schoolName.isNotEmpty &&
          isLoggedIn == true) {
        
        // Auto-navigate to the role selection screen if school token exists
        if (mounted) {
          print('🏫 Found existing school with login, navigating to role selection');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RoleSelectionScreen(
                schoolName: schoolName,
                schoolToken: schoolToken,
                schoolAddress: schoolAddress ?? 'No address available',
                schoolPhone: schoolPhone ?? 'No phone available',
              ),
            ),
          );
        }
      } else {
        print('🏫 No existing school found or not logged in, staying on school selection screen');
      }
    } catch (e) {
      print('⚠️ Error checking for existing school: $e');
      // Continue showing the school selection screen
    }
  }
  
  // Load schools from API
  Future<void> _loadSchools() async {
    setState(() {
      _isLoadingSchools = true;
      _errorMessage = '';
    });

    try {
      // Changed from localhost to a network IP address format
      final apiBaseUrl = Constants.apiBaseUrl; // Use the constant for base URL
      final url = '$apiBaseUrl/schools/';
      
      print('🔍 Attempting to connect to API at: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Accept": "application/json",
          "Access-Control-Allow-Origin": "*", 
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null && jsonData['data']['schools'] != null) {
          final schoolsData = jsonData['data']['schools'] as List;
          
          setState(() {
            _schools = schoolsData.map((school) => {
              'id': school['_id'],
              'name': school['name'],
              'token': school['token'] ?? school['_id'], 
              'address': school['address'] ?? 'No address available',
              'phone': school['phone'] ?? 'No phone available',
              'secretKey': school['secretKey'] ?? 'qwerty',
              'teachers': school['teachers'] ?? [],
              'students': school['students'] ?? [],
              'classes': school['classes'] ?? [],
              'parents': school['parents'] ?? [],
            }).toList();
          });
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load schools. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load schools. Please check your network connection.';
        _schools = [];
      });
      
      // Show API configuration dialog if there's an error
      _showApiConfigDialog(e.toString());
    } finally {
      setState(() {
        _isLoadingSchools = false;
      });
    }
  }
  
  // Show dialog to configure API URL
  void _showApiConfigDialog(String errorMessage) {
    if (!mounted) return;
    
    final apiUrlController = TextEditingController();
    
    // Load current API URL if available
    StorageUtil.getString('apiBaseUrl').then((currentUrl) {
      apiUrlController.text = currentUrl ?? Constants.apiBaseUrl; // Use the constant as default
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('API Connection Error'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Could not connect to the API server. When debugging on a mobile device:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
              
                  const Text('• Use your laptop\'s IP address, not localhost'),
                  const Text('• Ensure your phone and laptop are on the same WiFi network'),
                  const Text('• Make sure your backend server is running'),
                 
                  const Text('To find your laptop\'s IP address:'),
                  const Text('• Windows: Run "ipconfig" in Command Prompt'),
                  const Text('• Mac: Go to System Preferences > Network'),
                  const Text('• Linux: Run "ifconfig" or "ip addr" in terminal'),
                  
                  const Text('Error details:'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('API Configuration:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText:Constants.apiBaseUrl,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Replace "192.168.162.52" with your laptop\'s actual IP address.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newUrl = apiUrlController.text.trim();
                  if (newUrl.isNotEmpty) {
                    await StorageUtil.setString('apiBaseUrl', newUrl);
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop();
                      // Retry loading schools with new URL
                      _loadSchools();
                    }
                  }
                },
                child: const Text('Save & Retry'),
              ),
            ],
          );
        },
      );
    });
  }
  
  Future<void> _verifyAndStoreSchool(String schoolId) async {
    setState(() {
      _isLoading = true;
    });
    
    // Find matching school
    final schoolMatch = _schools.firstWhere(
      (school) => school['id'].toString() == schoolId.trim(),
      orElse: () => {}, // Empty map if not found
    );

    // Check if we found a match
    if (schoolMatch.isNotEmpty) {
      // Use our storage utility to store the data
      await StorageUtil.setString('schoolToken', schoolMatch['token']);
      await StorageUtil.setString('schoolName', schoolMatch['name']);
      await StorageUtil.setString('schoolId', schoolMatch['id']);
      await StorageUtil.setString('schoolAddress', schoolMatch['address']);
      await StorageUtil.setString('schoolPhone', schoolMatch['phone']);
      await StorageUtil.setString('schoolSecretKey', schoolMatch['secretKey']);
      
      // Store arrays of IDs as JSON strings
      await StorageUtil.setString('schoolTeachers', json.encode(schoolMatch['teachers'] ?? []));
      await StorageUtil.setString('schoolStudents', json.encode(schoolMatch['students'] ?? []));
      await StorageUtil.setString('schoolClasses', json.encode(schoolMatch['classes'] ?? []));
      await StorageUtil.setString('schoolParents', json.encode(schoolMatch['parents'] ?? []));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionScreen(
              schoolName: schoolMatch['name'],
              schoolToken: schoolMatch['token'],
              schoolAddress: schoolMatch['address'],
              schoolPhone: schoolMatch['phone'],
            ),
          ),
        );
      }
    } else {
      // If exact match not found, try partial match by name
      final partialMatches = _schools.where(
        (school) => school['name'].toString().toLowerCase().contains(schoolId.trim().toLowerCase())
      ).toList();
      
      if (partialMatches.isNotEmpty) {
        // Use the first partial match
        final match = partialMatches.first;
        
        // Store the data using our utility
        await StorageUtil.setString('schoolToken', match['token']);
        await StorageUtil.setString('schoolName', match['name']);
        await StorageUtil.setString('schoolId', match['id']);
        await StorageUtil.setString('schoolAddress', match['address']);
        await StorageUtil.setString('schoolPhone', match['phone']);
        await StorageUtil.setString('schoolSecretKey', match['secretKey']);

        // Store arrays of IDs as JSON strings
        await StorageUtil.setString('schoolTeachers', json.encode(match['teachers'] ?? []));
        await StorageUtil.setString('schoolStudents', json.encode(match['students'] ?? []));
        await StorageUtil.setString('schoolClasses', json.encode(match['classes'] ?? []));
        await StorageUtil.setString('schoolParents', json.encode(match['parents'] ?? []));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RoleSelectionScreen(
                schoolName: match['name'],
                schoolToken: match['token'],
                schoolAddress: match['address'],
                schoolPhone: match['phone'],
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid school ID. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get colors from theme
    final primaryColor = AppTheme.getPrimaryColor(_currentTheme);
    final accentColor = AppTheme.getAccentColor(_currentTheme);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade200,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo with enhanced shadow and glow
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school,
                        size: 70,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Title with enhanced styling
                  Text(
                    'Welcome to School Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      shadows: [
                        Shadow(
                          color: Colors.white,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Subtitle with better contrast
                  Text(
                    'Please select your school to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: const Color(0xFF505050),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Enhanced form card with better styling
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: primaryColor.withValues(alpha: 0.4),
                    // Explicitly set the card color to white
                    color: Colors.white, 
                    surfaceTintColor: Colors.white, // Important for Material 3
                    clipBehavior: Clip.antiAlias, // Ensures content doesn't bleed outside rounded corners
                    child: Container(
                      // Add a container with explicit background decoration
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Enhanced input field
                              TextFormField(
                                controller: _schoolIdController,
                                decoration: InputDecoration(
                                  labelText: 'School ID',
                                  labelStyle: TextStyle(color: primaryColor),
                                  hintText: 'Enter your school ID (e.g., SCH001)',
                                  hintStyle: TextStyle(color: Colors.grey[400]),

                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: accentColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  prefixIcon: Icon(Icons.business, color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF424242),
                                  fontWeight: FontWeight.w500,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your school ID';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              // Enhanced button
                              ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          _verifyAndStoreSchool(_schoolIdController.text);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 54),
                                  elevation: 4,
                                  shadowColor: primaryColor.withValues(alpha: 0.5),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : const Text(
                                        'Continue',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Enhanced demo section label
                  Text(
                    'Available Schools:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF424242),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Loading indicator or error message
                  if (_isLoadingSchools)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    )
                  else if (_errorMessage.isNotEmpty)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    )
                  else if (_schools.isEmpty)
                    Card(
                      color: Colors.grey.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No schools available at the moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  // Enhanced school cards with better styling
                  else 
                    ...List.generate(_schools.length, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _schoolIdController.text = _schools[index]['id'],
                        borderRadius: BorderRadius.circular(12),
                        splashColor: primaryColor.withValues(alpha: 0.1),
                        highlightColor: primaryColor.withValues(alpha: 0.05),
                        child: Card(
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          elevation: 3,
                          shadowColor: accentColor.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.school_outlined,
                                    color: accentColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_schools[index]['name']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF424242),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${_schools[index]['id']}',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
 
}













