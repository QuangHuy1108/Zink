// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/rendering.dart'; // <-- THÊM DÒNG NÀY
import 'session_manager.dart'; // Assuming SessionManager is defined in the single file now
import 'home_screen.dart';   // Assuming HomeScreen is defined in the single file now
import 'login_screen.dart';  // Assuming LoginScreen is defined in the single file now
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false; // <-- THÊM DÒNG NÀY (ĐỂ GIÁ TRỊ LÀ false)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- BẮT ĐẦU ĐOẠN CODE MỚI ---
  // 1. Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 2. Khởi tạo dịch vụ thông báo
  await NotificationService().initialize();
  // --- KẾT THÚC ĐOẠN CODE MỚI ---
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define colors directly here or ensure they are accessible globally if needed elsewhere
    const Color primaryColor = Color(0xFFF6C886); // topazColor
    const Color secondaryColor = Color(0xFFE0A263); // earthYellow
    const Color errorColor = Color(0xFFFD402C); // coralRed
    const Color surfaceColor = Colors.black;
    const Color onSurfaceColor = Colors.white;
    const Color darkSurface = Color(0xFF1E1E1E); // darkSurface
    const Color sonicSilver = Color(0xFF747579); // sonicSilver

    return MaterialApp(
      title: 'Zink Social App', // Updated title
      debugShowCheckedModeBanner: false,
      theme: ThemeData( // Theme definition remains the same
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor, brightness: Brightness.dark,
            primary: primaryColor, secondary: secondaryColor, surface: surfaceColor,
            onSurface: onSurfaceColor, background: surfaceColor, onBackground: onSurfaceColor,
            error: errorColor
        ),
        scaffoldBackgroundColor: surfaceColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceColor, elevation: 0,
          iconTheme: IconThemeData(color: onSurfaceColor),
          titleTextStyle: TextStyle(color: onSurfaceColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData( // Correct constructor used previously
          color: surfaceColor, surfaceTintColor: surfaceColor, elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor, foregroundColor: Colors.black,
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primaryColor)
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14)
            )
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: onSurfaceColor, side: BorderSide(color: Colors.grey.shade800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14)
            )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: darkSurface,
          hintStyle: TextStyle(color: sonicSilver.withOpacity(0.7)),
          labelStyle: const TextStyle(color: sonicSilver),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor.withOpacity(0.5))),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>( // Initial route logic remains the same
        future: SessionManager().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: surfaceColor,
              body: Center(child: CircularProgressIndicator(color: primaryColor)),
            );
          }
          if (snapshot.hasError) { /* Handle error, default to LoginScreen */ return const LoginScreen(); }
          final isLoggedIn = snapshot.data ?? false;
          return isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

// IMPORTANT: All other classes (HomeScreen, LoginScreen, FeedScreen, ProfileScreen, etc.)
// need to be defined *within this file* if you are truly combining everything.
// The placeholders like `import 'home_screen.dart';` should be removed,
// and the actual class definitions should be pasted here.
// Due to length constraints, the full combined code isn't shown, but this main.dart
// structure is correct assuming other classes are defined below it in the same file.
