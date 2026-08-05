import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/chat_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/profile_screen.dart';
import 'services/voice_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeuroplanApp());
}

class NeuroplanApp extends StatelessWidget {
  const NeuroplanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C6CF0),
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      surface: const Color(0xFF121218),
      surfaceContainerHighest: const Color(0xFF1C1C26),
      surfaceContainer: const Color(0xFF1A1A22),
      primary: const Color(0xFF8C7CFF),
    );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return MaterialApp(
      title: 'NEUROPLAN AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D0D12),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A22),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8C7CFF), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8C7CFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF121218),
          indicatorColor: const Color(0xFF8C7CFF).withValues(alpha: 0.2),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? const Color(0xFF8C7CFF) : Colors.white60,
            );
          }),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isListening = false;

  final List<Widget> _screens = [
    const ChatScreen(),
    const TasksScreen(),
    const AgendaScreen(),
    const ProfileScreen(),
  ];

  final Map<String, int> _voiceRoutes = {
    'chat': 0,
    'tareas': 1,
    'tarea': 1,
    'agenda': 2,
    'calendario': 2,
    'perfil': 3,
  };

  Future<void> _handleVoiceCommand() async {
    if (_isListening) {
      await VoiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await VoiceService.initSpeech();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo activar el micrófono.')),
      );
      return;
    }

    setState(() => _isListening = true);
    VoiceService.startListening(
      onResult: (text) {
        final lower = text.toLowerCase();
        for (final entry in _voiceRoutes.entries) {
          if (lower.contains(entry.key)) {
            setState(() => _currentIndex = entry.value);
            VoiceService.speak('Abriendo ${entry.key}');
            return;
          }
        }
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleVoiceCommand,
        backgroundColor: _isListening ? Colors.redAccent : scheme.primary,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
