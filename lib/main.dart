import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'firebase_options.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isOffline = false;
  bool _initialized = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final status = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final offline = status == ConnectivityResult.none;
      if (mounted) {
        setState(() => _isOffline = offline);
      }
    });
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    final status = initial.isNotEmpty ? initial.first : ConnectivityResult.none;
    if (mounted) {
      setState(() {
        _isOffline = status == ConnectivityResult.none;
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isOffline ? const ProfilePage(showBack: false) : HomePage();
  }
}
