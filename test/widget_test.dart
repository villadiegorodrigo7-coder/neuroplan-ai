import 'package:flutter_test/flutter_test.dart';
import 'package:neuroplan_ai/models/task.dart';

void main() {
  group('Task: planificación semanal', () {
    test('conserva la fecha y el bloque al serializar y recuperar', () {
      final original = Task(
        id: 'task-1',
        title: 'Preparar informe',
        fecha: '2026-11-03',
        bloque: 'tarde',
      );

      final recuperada = Task.fromJson(original.toJson());

      expect(recuperada.id, 'task-1');
      expect(recuperada.title, 'Preparar informe');
      expect(recuperada.fecha, '2026-11-03');
      expect(recuperada.bloque, 'tarde');
      expect(recuperada.done, isFalse);
    });

    test('mantiene compatibles las tareas antiguas sin fecha ni bloque', () {
      final tareaAntigua = Task.fromJson({
        'id': 'task-legacy',
        'title': 'Leer',
        'done': false,
      });

      expect(tareaAntigua.fecha, isEmpty);
      expect(tareaAntigua.bloque, isEmpty);
    });
  });
}
