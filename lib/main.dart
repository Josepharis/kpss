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
import 'core/services/storage_cleanup_service.dart';
import 'core/services/firebase_data_uploader.dart';

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
    
    // Vatandaşlık dersi ekleme (sadece bir kez çalıştırılacak)
    try {
      print('📤 Uploading Vatandaşlık lesson to Firebase...');
      final uploader = FirebaseDataUploader();
      await uploader.uploadVatandaslikLessonData();
      print('✅ Vatandaşlık lesson uploaded!');
      print('💡 Konular otomatik olarak Storage\'dan çekilecek: dersler/vatandaslik/konular/');
    } catch (e) {
      print('❌ Vatandaşlık lesson upload error: $e');
    }
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
  
  // Run storage cleanup in background (non-blocking)
  _runStorageCleanup();
  
  runApp(const MyApp());
}

/// Run storage cleanup in background
Future<void> _runStorageCleanup() async {
  try {
    final cleanupService = StorageCleanupService();
    final deletedCount = await cleanupService.runCleanup();
    if (deletedCount > 0) {
      print('✅ Storage cleanup completed: $deletedCount files deleted');
    }
  } catch (e) {
    print('⚠️ Storage cleanup error: $e');
  }
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
  
  // Find MainScreen state from context
  static _MainScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Map<int, Widget> _pageCache = {};
  int _homePageKey = 0; // Key to force rebuild
  final GlobalKey _homePageStateKey = GlobalKey();

  Widget _getPage(int index) {
    if (index == 0) {
      // Always return fresh HomePage instance with unique key
      return HomePage(key: _homePageStateKey);
    }
    
    if (_pageCache.containsKey(index)) {
      return _pageCache[index]!;
    }
    
    Widget page;
    switch (index) {
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
        page = HomePage(key: ValueKey(_homePageKey));
    }
    
    if (index != 0) {
    _pageCache[index] = page;
    }
    return page;
  }

  void _onTabTapped(int index) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });
    
    // If returning to home page (index 0), refresh it by changing key
    if (index == 0 && previousIndex != 0) {
      setState(() {
        _homePageKey++; // Change key to force rebuild
      });
    }
  }
  
  // Public method to navigate to a tab
  void navigateToTab(int index) {
    _onTabTapped(index);
  }
  
  // Public method to refresh home page
  void refreshHomePage() {
    // Try to call refreshContent on HomePage state if available
    final homePageState = _homePageStateKey.currentState;
    if (homePageState != null) {
      // Use dynamic call to access refreshContent method
      try {
        (homePageState as dynamic).refreshContent();
        return;
      } catch (e) {
        // If method doesn't exist, fall through to rebuild
      }
    }
    // Fallback: rebuild if state not available
    setState(() {
      _homePageKey++; // Change key to force rebuild
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
