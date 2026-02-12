import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/home/pages/home_page.dart';
import 'features/home/pages/lessons_page.dart';
import 'features/home/pages/weaknesses_page.dart';
import 'features/home/pages/study_page.dart';
import 'features/home/pages/profile_page.dart';
import 'features/home/pages/ai_assistant_page.dart';
import 'core/widgets/custom_bottom_nav_bar.dart';
import 'features/auth/pages/splash_screen.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/register_page.dart';
import 'core/services/storage_cleanup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  int _themeKey = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('selected_theme') ?? 'Açık';
      setState(() {
        _isDarkMode = theme == 'Koyu';
      });
    } catch (e) {
      // Silent error handling
    }
  }

  void updateTheme(String theme) {
    setState(() {
      _isDarkMode = theme == 'Koyu';
      _themeKey++; // Force MaterialApp rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: MyApp.scaffoldMessengerKey,
      key: ValueKey(_themeKey),
      title: 'Kadrox',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
  State<MainScreen> createState() => MainScreenState();

  // Find MainScreen state from context
  static MainScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainScreenState>();
  }
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Map<int, Widget> _pageCache = {};
  final GlobalKey _homePageStateKey = GlobalKey();
  int _themeKey = 0; // Key to force rebuild when theme changes

  @override
  void initState() {
    super.initState();
    // Listen to theme changes from MyApp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkThemeChange();
    });
  }

  void _checkThemeChange() {
    // This will be called when theme changes
    // Theme changes are handled via refreshForThemeChange
  }

  void refreshForThemeChange() {
    _pageCache.clear();
    setState(() {
      _themeKey++;
    });
  }

  Widget _getPage(int index) {
    // Use theme key to force rebuild when theme changes
    if (_pageCache.containsKey(index) && _themeKey == 0) {
      return _pageCache[index]!;
    }

    Widget page;
    switch (index) {
      case 0:
        page = HomePage(
          key: _homePageStateKey, // Use stable GlobalKey
        );
        break;
      case 1:
        page = LessonsPage(key: ValueKey('lessons_$_themeKey'));
        break;
      case 2:
        page = WeaknessesPage(key: ValueKey('weaknesses_$_themeKey'));
        break;
      case 3:
        page = StudyPage(key: ValueKey('study_$_themeKey'));
        break;
      case 4:
        page = const AiAssistantPage();
        break;
      case 5:
        page = ProfilePage(key: ValueKey('profile_$_themeKey'));
        break;
      default:
        page = HomePage(key: _homePageStateKey);
    }

    if (_themeKey == 0) {
      _pageCache[index] = page;
    }
    return page;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      // If tapping same tab, optional: refresh or scroll to top
      if (index == 0) {
        refreshHomePage();
      }
      return;
    }

    setState(() {
      _currentIndex = index;
    });
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
      } catch (e) {
        // Method doesn't exist
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        key: ValueKey(_themeKey),
        index: _currentIndex,
        children: List.generate(6, (index) => _getPage(index)),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class SnackBarNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _dismissSnackBar();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _dismissSnackBar();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _dismissSnackBar();
  }

  void _dismissSnackBar() {
    MyApp.scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
  }
}
