import 'package:flutter/material.dart';
import 'auth/auth_api.dart';
import 'auth/auth_session.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class CreatorHubApp extends StatefulWidget {
  const CreatorHubApp({super.key, this.session});

  final AuthSession? session;

  @override
  State<CreatorHubApp> createState() => _State();
}

class _State extends State<CreatorHubApp> {
  late final AuthSession session;
  late final bool ownsSession;

  @override
  void initState() {
    super.initState();
    ownsSession = widget.session == null;
    session = widget.session ?? AuthSession(AuthApi());
    if (!session.ready) {
      session.restore();
    }
  }

  @override
  void dispose() {
    if (ownsSession) {
      session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CreatorHub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff635bff)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    ),
    home: ListenableBuilder(
      listenable: session,
      builder: (context, child) => !session.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session.signedIn
          ? HomeScreen(session: session)
          : LoginScreen(session: session),
    ),
  );
}
