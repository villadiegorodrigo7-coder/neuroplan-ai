import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NUEVO
import 'auth_gate.dart'; // NUEVO
import 'theme/app_theme.dart';
import 'screens/chat_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/mi_pulso_screen.dart';
import 'models/agenda_event.dart';
import 'services/agenda_avisos.dart';
import 'services/agenda_store.dart';
import 'services/diario_store.dart';
import 'services/recordatorio_diario.dart';

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
    return MaterialApp(
      title: 'NEUROPLAN AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      // En pantallas anchas (computador) la app se centra en una columna, en
      // vez de estirarse de lado a lado. En el teléfono no cambia nada.
      builder: (context, child) {
        final contenido = child ?? const SizedBox.shrink();
        if (MediaQuery.sizeOf(context).width <= AppTheme.anchoMaximo) {
          return contenido;
        }
        return ColoredBox(
          color: AppColors.fondoExterior,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppTheme.anchoMaximo),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: AppColors.borde),
                  ),
                ),
                child: contenido,
              ),
            ),
          ),
        );
      },
      home: const AuthGate(),
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
  int _ultimaSeccionPrincipal = 1;

  void _salirDeAgora() {
    if (mounted) setState(() => _currentIndex = _ultimaSeccionPrincipal);
  }
  Timer? _vigilante;
  String? _avisoClave; // qué invitación está a la vista ('diario' o 'agenda:id')

  late final List<Widget> _screens = [
    ChatScreen(onExit: _salirDeAgora),
    const TasksScreen(),
    const AgendaScreen(),
    const MiPulsoScreen(),
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _evaluarAviso();
  }

  /// Decide qué invitación mostrar: primero los recordatorios de la Agenda
  /// que ya llegaron a su hora; si no hay, la invitación a registrar el semáforo en Mi Pulso.
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
        '¿Cómo fue tu día? Registra tu semáforo en Mi Pulso cuando quieras.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            _ocultarAviso();
            RecordatorioDiario.instance.descartarHoy();
            setState(() => _currentIndex = 3);
          },
          child: const Text('Abrir Mi Pulso'),
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
      bottomNavigationBar: _currentIndex == 0 ? null : NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            if (index != 0) _ultimaSeccionPrincipal = index;
            _currentIndex = index;
          });
          // Al entrar a Tareas se sincroniza la matriz independiente.
          if (index == 1) TasksScreen.recargar.value++;
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
            icon: Icon(Icons.graphic_eq_outlined),
            selectedIcon: Icon(Icons.graphic_eq),
            label: 'Mi Pulso',
          ),
        ],
      ),
    );
  }
}
