/// Tarea de la pantalla "Tareas".
///
/// [origen] y [cuadrante] son opcionales y solo se llenan cuando la tarea
/// viene de la Matriz de Eisenhower del Cuadernillo (Etapa 2). Las tareas
/// creadas a mano los dejan en null, y el JSON viejo (sin estos campos)
/// se sigue leyendo sin problema.
class Task {
  final String id;
  String title;
  bool done;

  /// De dónde viene la tarea (por ahora solo 'eisenhower'), o null si la
  /// creó el usuario directamente en Tareas.
  String? origen;

  /// Clave del cuadrante de la matriz (ej. 'urgenteImportante'), o null.
  String? cuadrante;

  /// Día al que se llevó la tarea, como "2026-10-28". Vacío = sin día.
  String fecha;

  /// Bloque de ese día: 'manana', 'tarde' o 'noche'. Vacío = sin bloque.
  String bloque;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.origen,
    this.cuadrante,
    this.fecha = '',
    this.bloque = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        if (origen != null) 'origen': origen,
        if (cuadrante != null) 'cuadrante': cuadrante,
        if (fecha.isNotEmpty) 'fecha': fecha,
        if (bloque.isNotEmpty) 'bloque': bloque,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        done: json['done'] ?? false,
        origen: json['origen'],
        cuadrante: json['cuadrante'],
        fecha: (json['fecha'] ?? '').toString(),
        bloque: (json['bloque'] ?? '').toString(),
      );
}
