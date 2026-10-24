import '../models/entrada_diario.dart';
import 'coleccion_nube.dart';

/// Mi diario: se guarda en el dispositivo (por cuenta) y se sincroniza con la
/// tabla "diario" de Supabase. Es privado: solo lo lee su dueña o dueño.
class DiarioService {
  static final ColeccionNube<EntradaDiario> _col = ColeccionNube<EntradaDiario>(
    tabla: 'diario',
    claveLocal: 'diario_cache',
    idDe: (e) => e.id,
    aJson: (e) => e.toJson(),
    deJson: EntradaDiario.fromJson,
    aFila: (e, uid) => e.aFila(uid),
    deFila: EntradaDiario.deFila,
  );

  static Future<List<EntradaDiario>> cargar() => _col.cargar();

  static Future<void> guardar(List<EntradaDiario> entradas) =>
      _col.guardar(entradas);
}
