diff --git a/lib/screens/chat_screen.dart b/lib/screens/chat_screen.dart
index 2a837b5..e6ff040 100644
--- a/lib/screens/chat_screen.dart
+++ b/lib/screens/chat_screen.dart
@@ -101,7 +101,7 @@ class _ChatScreenState extends State<ChatScreen> {
         .map((m) => {'role': m.role, 'content': m.content})
         .toList();
 
-    final contexto = await _construirContextoRuedaVida();
+    final contexto = await _construirContextoUsuario();
 
     final response = await GeminiService.sendMessage(
       text,
@@ -122,19 +122,89 @@ class _ChatScreenState extends State<ChatScreen> {
     }
   }
 
-  /// Arma un resumen corto de la Rueda de la Vida para dárselo al agente
-  /// como contexto real, solo si el usuario ya completó la Etapa 1
-  /// (si no, los valores son solo el default en 5 y no dicen nada de la
-  /// persona real).
-  Future<String?> _construirContextoRuedaVida() async {
+  /// Arma el contexto de la Etapa 1 (diagnóstico, Rueda de la Vida y
+  /// consumo de tiempo) para dárselo al agente.
+  ///
+  /// Ya NO exige que la Etapa 1 esté marcada como completada: si el usuario
+  /// solo avanzó una parte, se envía lo que exista. Como los valores
+  /// numéricos arrancan en 5 por defecto, un 5 puede ser "no tocado" o un
+  /// 5 real. Por eso, si la etapa no está completada, solo se incluye cada
+  /// bloque numérico cuando algún valor se movió del 5, y se avisa al agente
+  /// de que los datos son parciales.
+  Future<String?> _construirContextoUsuario() async {
     final data = await CuadernilloService.cargar();
-    if (!data.etapa1Completada) return null;
+    final completa = data.etapa1Completada;
 
+    final bloques = <String>[];
+
+    // --- Diagnóstico inicial ---
+    final d = data.diagnosticoInicial;
+    final diagTocado = d.energia != 5 ||
+        d.estres != 5 ||
+        d.claridadMental != 5 ||
+        d.organizacion != 5 ||
+        d.motivacion != 5 ||
+        d.satisfaccionGeneral != 5;
+    if (completa || diagTocado) {
+      bloques.add('Diagnóstico inicial (escala 0-10): '
+          'Energía ${d.energia}, Estrés ${d.estres}, '
+          'Claridad mental ${d.claridadMental}, '
+          'Organización ${d.organizacion}, Motivación ${d.motivacion}, '
+          'Satisfacción general ${d.satisfaccionGeneral}.');
+    }
+    if (d.nota.trim().isNotEmpty) {
+      bloques.add('Nota del usuario en el diagnóstico: ${_recortar(d.nota)}');
+    }
+
+    // --- Rueda de la Vida ---
     final r = data.ruedaVida;
-    return "Rueda de la Vida del usuario (escala 0-10): "
-        "Salud ${r.salud}, Estudios ${r.estudios}, Trabajo ${r.trabajo}, "
-        "Finanzas ${r.finanzas}, Familia ${r.familia}, Amigos ${r.amigos}, "
-        "Descanso ${r.descanso}, Crecimiento personal ${r.crecimiento}.";
+    final ruedaTocada = r.salud != 5 ||
+        r.estudios != 5 ||
+        r.trabajo != 5 ||
+        r.finanzas != 5 ||
+        r.familia != 5 ||
+        r.amigos != 5 ||
+        r.descanso != 5 ||
+        r.crecimiento != 5;
+    if (completa || ruedaTocada) {
+      bloques.add('Rueda de la Vida (escala 0-10): '
+          'Salud ${r.salud}, Estudios ${r.estudios}, Trabajo ${r.trabajo}, '
+          'Finanzas ${r.finanzas}, Familia ${r.familia}, '
+          'Amigos ${r.amigos}, Descanso ${r.descanso}, '
+          'Crecimiento personal ${r.crecimiento}.');
+    }
+
+    // --- Distribución / consumo de tiempo (texto libre) ---
+    final t = data.consumoTiempo;
+    final tiempo = <String>[
+      if (t.redesSociales.trim().isNotEmpty)
+        'Redes sociales: ${_recortar(t.redesSociales)}',
+      if (t.distracciones.trim().isNotEmpty)
+        'Distracciones: ${_recortar(t.distracciones)}',
+      if (t.obligaciones.trim().isNotEmpty)
+        'Obligaciones: ${_recortar(t.obligaciones)}',
+      if (t.habitos.trim().isNotEmpty) 'Hábitos: ${_recortar(t.habitos)}',
+    ];
+    if (tiempo.isNotEmpty) {
+      bloques.add('Cómo usa su tiempo el usuario. ${tiempo.join(' | ')}');
+    }
+
+    // Nada real todavía: no mandamos contexto (evita que el agente
+    // trate los valores por defecto como si fueran datos de la persona).
+    if (bloques.isEmpty) return null;
+
+    final estado = completa
+        ? 'Etapa 1 del Cuadernillo completada.'
+        : 'Etapa 1 del Cuadernillo en progreso: son datos PARCIALES; lo que '
+            'falte aún no lo ha respondido, no lo des por hecho.';
+
+    return '$estado\n${bloques.join('\n')}';
+  }
+
+  /// Limita el largo de textos libres para no inflar el prompt.
+  String _recortar(String texto, {int max = 300}) {
+    final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
+    return limpio.length <= max ? limpio : '${limpio.substring(0, max)}…';
   }
 
   void _scrollToBottom() {
diff --git a/lib/screens/etapa2_priorizar_screen.dart b/lib/screens/etapa2_priorizar_screen.dart
index 82cdb9e..c4e6d63 100644
--- a/lib/screens/etapa2_priorizar_screen.dart
+++ b/lib/screens/etapa2_priorizar_screen.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/material.dart';
 import 'package:google_fonts/google_fonts.dart';
 import '../models/cuadernillo_data.dart';
+import '../services/auto_guardado.dart';
 import '../services/cuadernillo_service.dart';
 
 const Color kMorado = Color(0xFF8C7CFF);
@@ -25,6 +26,12 @@ class _Etapa2PriorizarScreenState extends State<Etapa2PriorizarScreen> {
   final _controllerUNI = TextEditingController();
   final _controllerNN = TextEditingController();
 
+  /// Guardado automático con debounce (ver services/auto_guardado.dart).
+  late final AutoGuardado _auto = AutoGuardado(
+    obtenerDatos: () => _data,
+    sincronizar: _sincronizar,
+  );
+
   @override
   void initState() {
     super.initState();
@@ -39,11 +46,40 @@ class _Etapa2PriorizarScreenState extends State<Etapa2PriorizarScreen> {
     });
   }
 
+  /// Se ejecuta justo antes de cada escritura. Las tareas ya viven en el
+  /// modelo (se agregan/eliminan directo sobre las listas), así que lo único
+  /// "suelto" son los textos escritos que el usuario aún no agregó con el
+  /// botón +. Esos se confirman solo cuando el usuario sale de la pantalla
+  /// o la app pasa a segundo plano, nunca mientras escribe (para no guardar
+  /// tareas a medias).
+  void _sincronizar(MotivoGuardado motivo) {
+    if (motivo == MotivoGuardado.debounce) return;
+    final m = _data.matrizEisenhower;
+    final refrescar = motivo != MotivoGuardado.cierre;
+    _confirmarBorrador(m.urgenteImportante, _controllerUI, refrescar);
+    _confirmarBorrador(m.importanteNoUrgente, _controllerINU, refrescar);
+    _confirmarBorrador(m.urgenteNoImportante, _controllerUNI, refrescar);
+    _confirmarBorrador(m.niUrgenteNiImportante, _controllerNN, refrescar);
+  }
+
+  void _confirmarBorrador(
+    List<String> lista,
+    TextEditingController controller,
+    bool refrescar,
+  ) {
+    final texto = controller.text.trim();
+    if (texto.isEmpty) return;
+    lista.add(texto);
+    controller.clear();
+    // No se puede llamar setState mientras la pantalla se está cerrando.
+    if (refrescar && mounted) setState(() {});
+  }
+
   Future<void> _guardar({bool completar = false}) async {
-    setState(() => _guardando = true);
     if (completar) _data.etapa2Completada = true;
-    await CuadernilloService.guardar(_data);
-    setState(() => _guardando = false);
+    setState(() => _guardando = true);
+    await _auto.guardarAhora();
+    if (mounted) setState(() => _guardando = false);
   }
 
   void _agregarTarea(List<String> lista, TextEditingController controller) {
@@ -53,10 +89,12 @@ class _Etapa2PriorizarScreenState extends State<Etapa2PriorizarScreen> {
       lista.add(texto);
       controller.clear();
     });
+    _auto.programar(); // cambio en el modelo => guardado automático
   }
 
   void _eliminarTarea(List<String> lista, int index) {
     setState(() => lista.removeAt(index));
+    _auto.programar();
   }
 
   Future<void> _finalizar() async {
@@ -74,6 +112,9 @@ class _Etapa2PriorizarScreenState extends State<Etapa2PriorizarScreen> {
 
   @override
   void dispose() {
+    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
+    // los controllers, porque _sincronizar los lee).
+    _auto.dispose();
     _controllerUI.dispose();
     _controllerINU.dispose();
     _controllerUNI.dispose();
diff --git a/lib/screens/etapa3_organizar_screen.dart b/lib/screens/etapa3_organizar_screen.dart
index 4a764d9..39c4650 100644
--- a/lib/screens/etapa3_organizar_screen.dart
+++ b/lib/screens/etapa3_organizar_screen.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/material.dart';
 import 'package:google_fonts/google_fonts.dart';
 import '../models/cuadernillo_data.dart';
+import '../services/auto_guardado.dart';
 import '../services/cuadernillo_service.dart';
 
 const Color kMorado = Color(0xFF8C7CFF);
@@ -25,6 +26,13 @@ class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
   final _tardeController = TextEditingController();
   final _nocheController = TextEditingController();
 
+  /// Guardado automático con debounce (ver services/auto_guardado.dart).
+  /// Antes de cada escritura copia los 3 campos del día visible al modelo.
+  late final AutoGuardado _auto = AutoGuardado(
+    obtenerDatos: () => _data,
+    sincronizar: (_) => _guardarDiaActual(),
+  );
+
   @override
   void initState() {
     super.initState();
@@ -60,14 +68,14 @@ class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
       _diaSeleccionado = index;
       _cargarDiaEnControladores();
     });
+    _auto.programar();
   }
 
   Future<void> _guardar({bool completar = false}) async {
-    _guardarDiaActual();
-    setState(() => _guardando = true);
     if (completar) _data.etapa3Completada = true;
-    await CuadernilloService.guardar(_data);
-    setState(() => _guardando = false);
+    setState(() => _guardando = true);
+    await _auto.guardarAhora(); // copia el día visible al modelo y guarda
+    if (mounted) setState(() => _guardando = false);
   }
 
   Future<void> _finalizar() async {
@@ -85,6 +93,9 @@ class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
 
   @override
   void dispose() {
+    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
+    // los controllers, porque la sincronización los lee).
+    _auto.dispose();
     _mananaController.dispose();
     _tardeController.dispose();
     _nocheController.dispose();
@@ -193,6 +204,7 @@ class _Etapa3OrganizarScreenState extends State<Etapa3OrganizarScreen> {
           child: TextField(
             controller: controller,
             maxLines: 3,
+            onChanged: (_) => _auto.programar(), // guardado automático
             style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
             decoration: InputDecoration(
               hintText: 'Qué harás en este bloque...',
diff --git a/lib/screens/etapa4_seguimiento_screen.dart b/lib/screens/etapa4_seguimiento_screen.dart
index cb551b5..2b69c57 100644
--- a/lib/screens/etapa4_seguimiento_screen.dart
+++ b/lib/screens/etapa4_seguimiento_screen.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/material.dart';
 import 'package:google_fonts/google_fonts.dart';
 import '../models/cuadernillo_data.dart';
+import '../services/auto_guardado.dart';
 import '../services/cuadernillo_service.dart';
 
 const Color kMorado = Color(0xFF8C7CFF);
@@ -24,6 +25,12 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
   final _nuevaTareaController = TextEditingController();
   final _notaController = TextEditingController();
 
+  /// Guardado automático con debounce (ver services/auto_guardado.dart).
+  late final AutoGuardado _auto = AutoGuardado(
+    obtenerDatos: () => _data,
+    sincronizar: _sincronizar,
+  );
+
   @override
   void initState() {
     super.initState();
@@ -41,12 +48,28 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
 
   RegistroDiario get _registroActual => _data.seguimiento30Dias.registros[_diaSeleccionado];
 
+  /// Se ejecuta justo antes de cada escritura: copia la nota del día
+  /// visible al modelo. Si el usuario escribió una tarea pero no pulsó +,
+  /// se confirma solo al salir o al pasar a segundo plano (nunca mientras
+  /// escribe, para no guardar tareas a medias).
+  void _sincronizar(MotivoGuardado motivo) {
+    _registroActual.nota = _notaController.text;
+    if (motivo == MotivoGuardado.debounce) return;
+    final texto = _nuevaTareaController.text.trim();
+    if (texto.isEmpty) return;
+    _registroActual.tareas.add(TareaChecklist(texto: texto));
+    _nuevaTareaController.clear();
+    // No se puede llamar setState mientras la pantalla se está cerrando.
+    if (motivo != MotivoGuardado.cierre && mounted) setState(() {});
+  }
+
   void _cambiarDia(int index) {
     _registroActual.nota = _notaController.text;
     setState(() {
       _diaSeleccionado = index;
       _notaController.text = _registroActual.nota;
     });
+    _auto.programar();
   }
 
   void _agregarTarea() {
@@ -56,24 +79,26 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
       _registroActual.tareas.add(TareaChecklist(texto: texto));
       _nuevaTareaController.clear();
     });
+    _auto.programar();
   }
 
   void _toggleTarea(int index) {
     setState(() {
       _registroActual.tareas[index].completada = !_registroActual.tareas[index].completada;
     });
+    _auto.programar();
   }
 
   void _eliminarTarea(int index) {
     setState(() => _registroActual.tareas.removeAt(index));
+    _auto.programar();
   }
 
   Future<void> _guardar({bool completar = false}) async {
-    _registroActual.nota = _notaController.text;
-    setState(() => _guardando = true);
     if (completar) _data.etapa4Completada = true;
-    await CuadernilloService.guardar(_data);
-    setState(() => _guardando = false);
+    setState(() => _guardando = true);
+    await _auto.guardarAhora(); // copia la nota al modelo y guarda
+    if (mounted) setState(() => _guardando = false);
   }
 
   Future<void> _finalizar() async {
@@ -91,6 +116,9 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
 
   @override
   void dispose() {
+    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
+    // los controllers, porque la sincronización los lee).
+    _auto.dispose();
     _nuevaTareaController.dispose();
     _notaController.dispose();
     super.dispose();
@@ -179,9 +207,11 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
                   const SizedBox(height: 20),
                   _buildSlider('Estado de ánimo', registro.estadoAnimo, (v) {
                     setState(() => registro.estadoAnimo = v);
+                    _auto.programar();
                   }),
                   _buildSlider('Nivel de cumplimiento (%)', registro.nivelCumplimiento, (v) {
                     setState(() => registro.nivelCumplimiento = v);
+                    _auto.programar();
                   }, max: 100, divisions: 10, sufijo: '%'),
                   const SizedBox(height: 8),
                   _buildCampoTexto(_notaController, 'Nota del día', '¿Cómo te fue hoy?'),
@@ -317,6 +347,7 @@ class _Etapa4SeguimientoScreenState extends State<Etapa4SeguimientoScreen> {
           child: TextField(
             controller: controller,
             maxLines: 3,
+            onChanged: (_) => _auto.programar(), // guardado automático
             style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
             decoration: InputDecoration(
               hintText: hint,
diff --git a/lib/screens/etapa5_evaluar_screen.dart b/lib/screens/etapa5_evaluar_screen.dart
index fc18bb0..b292f7d 100644
--- a/lib/screens/etapa5_evaluar_screen.dart
+++ b/lib/screens/etapa5_evaluar_screen.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/material.dart';
 import 'package:google_fonts/google_fonts.dart';
 import '../models/cuadernillo_data.dart';
+import '../services/auto_guardado.dart';
 import '../services/cuadernillo_service.dart';
 
 const Color kMorado = Color(0xFF8C7CFF);
@@ -24,6 +25,12 @@ class _Etapa5EvaluarScreenState extends State<Etapa5EvaluarScreen> {
   final _queNoFuncionoController = TextEditingController();
   final _proximosPasosController = TextEditingController();
 
+  /// Guardado automático con debounce (ver services/auto_guardado.dart).
+  late final AutoGuardado _auto = AutoGuardado(
+    obtenerDatos: () => _data,
+    sincronizar: (_) => _copiarControladoresAlModelo(),
+  );
+
   @override
   void initState() {
     super.initState();
@@ -41,14 +48,18 @@ class _Etapa5EvaluarScreenState extends State<Etapa5EvaluarScreen> {
     });
   }
 
-  Future<void> _guardar({bool completar = false}) async {
+  /// Copia los 3 textos al modelo. Se ejecuta antes de cada escritura.
+  void _copiarControladoresAlModelo() {
     _data.evaluacionFinal.queFunciono = _queFuncionoController.text;
     _data.evaluacionFinal.queNoFunciono = _queNoFuncionoController.text;
     _data.evaluacionFinal.proximosPasos = _proximosPasosController.text;
-    setState(() => _guardando = true);
+  }
+
+  Future<void> _guardar({bool completar = false}) async {
     if (completar) _data.etapa5Completada = true;
-    await CuadernilloService.guardar(_data);
-    setState(() => _guardando = false);
+    setState(() => _guardando = true);
+    await _auto.guardarAhora(); // copia los textos al modelo y guarda
+    if (mounted) setState(() => _guardando = false);
   }
 
   Future<void> _finalizar() async {
@@ -66,6 +77,9 @@ class _Etapa5EvaluarScreenState extends State<Etapa5EvaluarScreen> {
 
   @override
   void dispose() {
+    // Primero: cancela el timer y guarda lo pendiente (antes de liberar
+    // los controllers, porque la sincronización los lee).
+    _auto.dispose();
     _queFuncionoController.dispose();
     _queNoFuncionoController.dispose();
     _proximosPasosController.dispose();
@@ -133,6 +147,7 @@ class _Etapa5EvaluarScreenState extends State<Etapa5EvaluarScreen> {
           child: TextField(
             controller: controller,
             maxLines: 4,
+            onChanged: (_) => _auto.programar(), // guardado automático
             style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
             decoration: InputDecoration(
               hintText: hint,
diff --git a/lib/services/auto_guardado.dart b/lib/services/auto_guardado.dart
new file mode 100644
index 0000000..cbeb2b2
--- /dev/null
+++ b/lib/services/auto_guardado.dart
@@ -0,0 +1,159 @@
+import 'dart:async';
+
+import 'package:flutter/foundation.dart';
+import 'package:flutter/widgets.dart';
+
+import '../models/cuadernillo_data.dart';
+import 'cuadernillo_service.dart';
+
+/// Motivo por el que se está sincronizando/guardando. Permite que cada
+/// pantalla decida qué hacer (por ejemplo, confirmar o no un texto que el
+/// usuario escribió pero todavía no agregó a una lista).
+enum MotivoGuardado {
+  /// Pasó el tiempo de espera después de un cambio (guardado automático).
+  debounce,
+
+  /// El usuario pulsó "Guardar y salir" o "Finalizar".
+  explicito,
+
+  /// La app/pestaña pasó a segundo plano (o se está cerrando el navegador).
+  segundoPlano,
+
+  /// La pantalla se está cerrando (dispose). No se debe llamar setState.
+  cierre,
+}
+
+/// Guardado automático con "debounce" para el Cuadernillo.
+///
+/// Uso típico dentro de un State:
+///
+/// ```dart
+/// late final AutoGuardado _auto = AutoGuardado(
+///   obtenerDatos: () => _data,
+///   sincronizar: (motivo) { /* copiar controllers -> modelo */ },
+/// );
+///
+/// // tras cada cambio del usuario:
+/// _auto.programar();
+///
+/// @override
+/// void dispose() {
+///   _auto.dispose();          // cancela el timer Y guarda lo pendiente
+///   controller.dispose();     // después de _auto.dispose()
+///   super.dispose();
+/// }
+/// ```
+///
+/// Qué garantiza:
+///  * Muchos cambios seguidos => una sola escritura (cada [retraso]).
+///  * Nunca hay dos escrituras simultáneas; si llegan cambios mientras se
+///    guarda, se hace una escritura más al terminar.
+///  * Al cerrar la pantalla o pasar la app a segundo plano se guarda lo
+///    pendiente de inmediato (así no se pierde el último cambio).
+///  * No toca la estructura JSON de [CuadernilloData].
+class AutoGuardado extends WidgetsBindingObserver {
+  AutoGuardado({
+    required this.obtenerDatos,
+    this.sincronizar,
+    this.retraso = const Duration(milliseconds: 700),
+  }) {
+    WidgetsBinding.instance.addObserver(this);
+  }
+
+  /// Devuelve el modelo en memoria que se debe persistir.
+  final CuadernilloData Function() obtenerDatos;
+
+  /// Se llama justo antes de cada escritura para copiar lo que hay en los
+  /// TextEditingController al modelo.
+  final void Function(MotivoGuardado motivo)? sincronizar;
+
+  /// Tiempo de espera desde el último cambio (500-800 ms recomendado).
+  final Duration retraso;
+
+  Timer? _timer;
+  Future<void>? _enCurso;
+  bool _pendiente = false;
+  bool _liberado = false;
+
+  /// Hay cambios sin escribir en disco.
+  bool get hayPendientes => _pendiente;
+
+  /// Llamar después de CADA cambio hecho por el usuario.
+  void programar() {
+    if (_liberado) return;
+    _pendiente = true;
+    _timer?.cancel();
+    _timer = Timer(retraso, () => _ejecutar(MotivoGuardado.debounce));
+  }
+
+  /// Guarda ya (sin esperar el debounce) y completa cuando termina.
+  /// Úsalo en "Guardar y salir" / "Finalizar".
+  Future<void> guardarAhora({
+    MotivoGuardado motivo = MotivoGuardado.explicito,
+  }) {
+    if (_liberado) return Future.value();
+    _pendiente = true;
+    _timer?.cancel();
+    return _ejecutar(motivo);
+  }
+
+  Future<void> _ejecutar(MotivoGuardado motivo) {
+    _timer?.cancel();
+    // Si ya hay una escritura en curso, el bucle de _correr volverá a
+    // revisar _pendiente al terminar, así que reutilizamos ese Future.
+    return _enCurso ??= _correr(motivo).whenComplete(() => _enCurso = null);
+  }
+
+  Future<void> _correr(MotivoGuardado motivo) async {
+    while (_pendiente) {
+      _pendiente = false;
+      try {
+        sincronizar?.call(motivo);
+        await CuadernilloService.guardar(obtenerDatos());
+      } catch (e) {
+        // Un fallo de almacenamiento no debe romper la pantalla.
+        // Se deja el cambio como pendiente para reintentarlo en el
+        // próximo cambio y se sale del bucle para no ciclar.
+        debugPrint('AutoGuardado: error al guardar: $e');
+        _pendiente = true;
+        return;
+      }
+    }
+  }
+
+  /// Guardar al pasar a segundo plano: en web esto cubre cambiar de
+  /// pestaña o cerrar el navegador (visibilitychange).
+  @override
+  void didChangeAppLifecycleState(AppLifecycleState state) {
+    if (state != AppLifecycleState.resumed && _pendiente) {
+      guardarAhora(motivo: MotivoGuardado.segundoPlano);
+    }
+  }
+
+  /// Cancela el timer, deja de observar el ciclo de vida y, si había
+  /// cambios sin escribir, los guarda de inmediato (sin await).
+  ///
+  /// Llamar ANTES de liberar los TextEditingController.
+  void dispose() {
+    if (_liberado) return;
+    _timer?.cancel();
+    WidgetsBinding.instance.removeObserver(this);
+
+    if (_pendiente) {
+      _pendiente = false;
+      try {
+        sincronizar?.call(MotivoGuardado.cierre);
+        // Escritura "fire and forget": no depende del widget, solo del
+        // modelo en memoria, así que es seguro aunque la pantalla muera.
+        unawaited(
+          CuadernilloService.guardar(obtenerDatos()).catchError((Object e) {
+            debugPrint('AutoGuardado: error al guardar al cerrar: $e');
+          }),
+        );
+      } catch (e) {
+        debugPrint('AutoGuardado: error al cerrar: $e');
+      }
+    }
+    _liberado = true;
+  }
+}
