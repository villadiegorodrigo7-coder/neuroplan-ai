import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NUEVO
import 'auth_gate.dart'; // NUEVO
import 'screens/chat_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/profile_screen.dart';
import 'models/agenda_event.dart';
import 'services/agenda_avisos.dart';
import 'services/agenda_store.dart';
import 'services/diario_store.dart';
import 'services/recordatorio_diario.dart';
import 'services/reflexion_service.dart';

// NUEVO: main ahora es async e inicia Supabase
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hzisvmapqmadddejrerq.supabase.co',
    anonKey: 'sb_publishable_dx27o7FnPWhrkmY1tlA6tw_xoLcQr-T',
  );
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
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
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
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF8C7CFF),
              width: 1.5,
            ),
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
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color:
                  selected ? const Color(0xFF8C7CFF) : Colors.white60,
            );
          }),
        ),
      ),
      home: const AuthGate(), // NUEVO: antes era MainNavigation()
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _vigilante;
  String? _avisoClave; // qué invitación está a la vista ('diario' o 'agenda:id')

  final List<Widget> _screens = [
    const ChatScreen(),
    const TasksScreen(),
    const AgendaScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RecordatorioDiario.instance.addListener(_evaluarAviso);
    RecordatorioDiario.instance.cargar();
    DiarioStore.instance.addListener(_evaluarAviso);
    DiarioStore.instance.cargar();
    AgendaStore.instance.addListener(_evaluarAviso);
    AgendaStore.instance.cargar();
    AgendaAvisos.instance.addListener(_evaluarAviso);
    AgendaAvisos.instance.cargar();
    ReflexionService.instance.senal.addListener(_irAlChat);
    // Revisa cada 30 segundos mientras la app está abierta (es una
    // comparación local, no gasta datos).
    _vigilante = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _evaluarAviso(),
    );
  }

  @override
  void dispose() {
    _vigilante?.cancel();
    RecordatorioDiario.instance.removeListener(_evaluarAviso);
    DiarioStore.instance.removeListener(_evaluarAviso);
    AgendaStore.instance.removeListener(_evaluarAviso);
    AgendaAvisos.instance.removeListener(_evaluarAviso);
    ReflexionService.instance.senal.removeListener(_irAlChat);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _evaluarAviso();
  }

  /// "Reflexionar con Ágora": se pasa a la pestaña del chat.
  void _irAlChat() {
    if (mounted) setState(() => _currentIndex = 0);
  }

  /// Decide qué invitación mostrar: primero los recordatorios de la Agenda
  /// que ya llegaron a su hora; si no hay, la invitación a llenar Mi diario.
  void _evaluarAviso() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final evento = AgendaAvisos.instance.proximoVencido();
    String? clave;
    if (evento != null) {
      clave = 'agenda:${evento.id}';
    } else if (RecordatorioDiario.instance.debeAvisar()) {
      clave = 'diario';
    }

    if (clave == null) {
      if (_avisoClave != null) _ocultarAviso();
      return;
    }
    if (clave == _avisoClave) return;

    messenger.removeCurrentMaterialBanner();
    _avisoClave = clave;
    messenger.showMaterialBanner(
      evento != null ? _bannerAgenda(evento) : _bannerDiario(),
    );
  }

  MaterialBanner _bannerDiario() {
    return MaterialBanner(
      leading: const Icon(Icons.menu_book_rounded),
      content: const Text(
        '¿Cómo fue tu día? Marca tu semáforo en Mi diario cuando quieras.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            _ocultarAviso();
            RecordatorioDiario.instance.descartarHoy();
            setState(() => _currentIndex = 3);
          },
          child: const Text('Abrir Mi diario'),
        ),
        TextButton(
          onPressed: () {
            _ocultarAviso();
            RecordatorioDiario.instance.descartarHoy();
          },
          child: const Text('Ahora no'),
        ),
      ],
    );
  }

  MaterialBanner _bannerAgenda(AgendaEvent evento) {
    final hora = TimeOfDay.fromDateTime(evento.date).format(context);
    return MaterialBanner(
      leading: const Icon(Icons.notifications_active_outlined),
      content: Text('Recordatorio: ${evento.title} · $hora'),
      actions: [
        TextButton(
          onPressed: () {
            _ocultarAviso();
            AgendaAvisos.instance.marcarVisto(evento);
          },
          child: const Text('Listo'),
        ),
        TextButton(
          onPressed: () {
            _ocultarAviso();
            AgendaAvisos.instance.aplazar(evento, 10);
          },
          child: const Text('Aplazar 10 min'),
        ),
        TextButton(
          onPressed: () {
            _ocultarAviso();
            AgendaAvisos.instance.marcarVisto(evento);
            setState(() => _currentIndex = 2);
          },
          child: const Text('Ver agenda'),
        ),
      ],
    );
  }

  void _ocultarAviso() {
    _avisoClave = null;
    if (mounted) ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
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
