import 'package:flutter/material.dart';
import 'package:chronicle/database/database_helper.dart';
import 'package:chronicle/screens/home_screen.dart';

// main() é a primeira função chamada pelo Flutter.
// "async" indica que ela pode aguardar operações, como abrir o banco de dados.
void main() {
  // Esta linha DEVE vir primeiro ao usar plugins, como o sqflite.
  // Ela garante que o mecanismo do Flutter esteja pronto antes de qualquer ação.
  WidgetsFlutterBinding.ensureInitialized();

  // O SQLite funciona de formas diferentes no desktop e em dispositivos móveis.
  // Esta chamada configura a implementação correta para a plataforma atual.
  DatabaseHelper.initFfiIfNeeded();

  // Renderiza imediatamente; o SQLite é aberto no primeiro uso.
  runApp(const ChronicleApp());
}

// Todo aplicativo Flutter possui um widget raiz.
// StatelessWidget representa um widget sem estado mutável após sua construção.
/// Widget raiz que configura tema, navegação e inicialização do aplicativo.
class ChronicleApp extends StatelessWidget {
  const ChronicleApp({super.key});

  // build() descreve a aparência e o comportamento deste widget.
  // O Flutter chama este método sempre que precisa renderizar o widget.
  @override
  Widget build(BuildContext context) {
    // MaterialApp configura a navegação, os temas e a estrutura geral do aplicativo.
    return MaterialApp(
      title: 'Chronicle',
      debugShowCheckedModeBanner:
          false, // Oculta a faixa vermelha de depuração.

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E9E50)),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),

        // Estas duas linhas DESATIVAM os efeitos de toque e foco nos botões.
        // Isso evita uma falha de rastreamento do mouse durante a navegação no Windows.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),

      home: const DatabaseGate(),
    );
  }
}

/// Bloqueia a tela inicial até que o banco esteja pronto para uso.
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
    // Reinicia a validação após uma falha de abertura do banco.
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
