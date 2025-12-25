import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/home/pages/home_page.dart';
import 'features/home/pages/lessons_page.dart';
import 'features/home/pages/weaknesses_page.dart';
import 'features/home/pages/study_page.dart';
import 'features/home/pages/profile_page.dart';
import 'core/widgets/custom_bottom_nav_bar.dart';
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Data upload completed - removed upload code
    // If you need to upload data again, uncomment the code below:
    /*
    try {
      print('📤 Uploading Tarih lesson data to Firebase...');
      await uploadData();
    } catch (e) {
      print('❌ Data upload error: $e');
    }
    */
  } catch (e) {
    // Continue even if Firebase fails to initialize
    print('❌ Firebase initialization error: $e');
    print('Error type: ${e.runtimeType}');
  }
  
  // Initialize date formatting for Turkish locale
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    // Continue even if date formatting fails
    print('Date formatting initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KPSS & AGS 2026',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Map<int, Widget> _pageCache = {};

  Widget _getPage(int index) {
    if (_pageCache.containsKey(index)) {
      return _pageCache[index]!;
    }
    
    Widget page;
    switch (index) {
      case 0:
        page = const HomePage();
        break;
      case 1:
        page = const LessonsPage();
        break;
      case 2:
        page = const WeaknessesPage();
        break;
      case 3:
        page = const StudyPage();
        break;
      case 4:
        page = const ProfilePage();
        break;
      default:
        page = const HomePage();
    }
    
    _pageCache[index] = page;
    return page;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, (index) => _getPage(index)),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
