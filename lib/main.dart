import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'utils/storage_util.dart';
import 'screens/role_selection_screen.dart';
import 'utils/app_theme.dart';
import 'utils/theme_notifier.dart';
import 'models/user_model.dart';
import 'screens/school_admin_dashboard.dart';
import 'screens/student_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/parent_dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';

bool _isAppInitialized = false;

/// Global ThemeNotifier instance accessible across the app
final ThemeNotifier themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Firebase initialization info: $e');
    }
  }

  // Initialize FCM Service
  try {
    final fcmService = FCMService();
    await fcmService.initialize();
    if (kDebugMode) {
      print('🔔 FCM Service initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Error initializing FCM Service: $e');
    }
  }

  try {
    if (!_isAppInitialized) {
      _isAppInitialized = true;
      await StorageUtil.setString('app_initialized', DateTime.now().toString());
    } else {
      await StorageUtil.init();
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Error initializing storage: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set preferred orientations for mobile devices
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      print('🔄 App lifecycle state changed: $state');
    }
    if (state == AppLifecycleState.resumed) {
      StorageUtil.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'EduTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final isLoggedIn = await StorageUtil.getBool('isLoggedIn') ?? false;

      if (kDebugMode) {
        print('🔍 Checking login status: $isLoggedIn');
      }

      if (isLoggedIn) {
        await _restoreUserSession();
      } else {
        _navigateToSchoolSelection();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking login status: $e');
      }
      _navigateToSchoolSelection();
    }
  }

  Future<void> _restoreUserSession() async {
    try {
      final userId = await StorageUtil.getString('userId') ?? '';
      final userEmail = await StorageUtil.getString('userEmail') ?? '';
      final userRole = await StorageUtil.getString('userRole') ?? '';
      final userFirstName = await StorageUtil.getString('userFirstName') ?? '';
      final userLastName = await StorageUtil.getString('userLastName') ?? '';
      final userPhone = await StorageUtil.getString('userPhone') ?? '';
      final userAddress = await StorageUtil.getString('userAddress') ?? '';
      final userProfilePic = await StorageUtil.getString('userProfilePic') ?? '';
      final schoolToken = await StorageUtil.getString('schoolToken') ?? '';
      final schoolName = await StorageUtil.getString('schoolName') ?? '';

      if (userId.isEmpty || userEmail.isEmpty || userRole.isEmpty) {
        _navigateToSchoolSelection();
        return;
      }

      final user = User(
        id: userId,
        email: userEmail,
        role: userRole,
        schoolToken: schoolToken,
        schoolName: schoolName,
        profile: UserProfile(
          firstName: userFirstName,
          lastName: userLastName,
          phone: userPhone,
          address: userAddress,
          profilePicture: userProfilePic,
        ),
      );

      _navigateBasedOnRole(userRole, user);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error restoring user session: $e');
      }
      _navigateToSchoolSelection();
    }
  }

  void _navigateBasedOnRole(String role, User user) {
    if (!mounted) return;

    Widget destinationScreen;

    switch (role) {
      case 'school_admin':
        destinationScreen = SchoolAdminDashboard(user: user);
        break;
      case 'teacher':
        destinationScreen = TeacherDashboard(user: user);
        break;
      case 'student':
        destinationScreen = StudentDashboard(user: user);
        break;
      case 'parent':
        destinationScreen = ParentDashboard(user: user);
        break;
      default:
        _navigateToSchoolSelection();
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
    );
  }

  void _navigateToSchoolSelection() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const RoleSelectionScreen(
          schoolName: "",
          schoolToken: "",
          schoolAddress: "",
          schoolPhone: "",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'app_logo',
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 56,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'EduTrack',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'School Management System',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
