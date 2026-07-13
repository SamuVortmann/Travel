import 'package:flutter/material.dart';
import 'package:travel/database/database_helper.dart';
import 'package:travel/screens/home_screen.dart';

// main() is the first function Flutter calls.
// "async" means it can wait for things (like opening a database).
void main() {
  // This line MUST come first when you use plugins (like sqflite).
  // It makes sure Flutter's engine is ready before we do anything.
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite works differently on Windows/Linux/Mac vs Android/iOS.
  // This call sets up the right version for whatever platform we're on.
  DatabaseHelper.initFfiIfNeeded();

  // Draw immediately; SQLite opens on first use.
  runApp(const ChronicleApp());
}

// Every Flutter app has one root widget.
// StatelessWidget = a widget that never changes after it's built.
class ChronicleApp extends StatelessWidget {
  const ChronicleApp({super.key});

  // build() describes what this widget looks like / does.
  // Flutter calls this whenever it needs to draw this widget.
  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up navigation, themes, and the overall app structure.
    return MaterialApp(
      title: 'Chronicle',
      debugShowCheckedModeBanner: false, // hides the red "DEBUG" banner

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E9E50)),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),

        // These two lines DISABLE the ripple/hover effect on buttons.
        // This prevents a crash on Windows when navigating (mouse tracker bug).
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),

      home: const DatabaseGate(),
    );
  }
}

class DatabaseGate extends StatefulWidget {
  const DatabaseGate({super.key});

  @override
  State<DatabaseGate> createState() => _DatabaseGateState();
}

class _DatabaseGateState extends State<DatabaseGate> {
  late Future<void> _opening;

  @override
  void initState() {
    super.initState();
    _opening = DatabaseHelper.instance.validateDatabase();
  }

  void _retry() {
    setState(() {
      _opening = DatabaseHelper.instance.reopenDatabase().then(
        (_) => DatabaseHelper.instance.validateDatabase(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _opening,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const HomeScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF2F2F7),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storage_outlined,
                        size: 54,
                        color: Color(0xFF2E9E50),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível abrir seus dados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Seus momentos não foram apagados. Toque abaixo para tentar reparar a conexão com o SQLite.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Color(0xFFF2F2F7),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF2E9E50)),
                SizedBox(height: 16),
                Text('Preparando seus dados...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
