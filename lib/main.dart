import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'login_page.dart';
import 'registration_page.dart';
import 'main_app_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  print("Firebase: Initializing...");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase: Initialization Complete.");
  } catch (e) {
    print("Firebase: Initialization FAILED: $e");
    // Consider showing an error UI or stopping the app
    return;
  }
  print("Firebase: Running app...");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Define the initial route
      initialRoute: '/login',
      // Define the available routes
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegistrationPage(),
        // Define route for registration
        '/main': (context) => MainAppPage(),
        // Define route for main app
      },
      // You could also use home: LoginPage(), but routes are more flexible
      // home: LoginPage(),
    );
  }
}
