# NEUROPLAN AI — Instrucciones para compilar el APK

## Requisitos previos

1. **Flutter instalado** — descárgalo en https://flutter.dev/docs/get-started/install
2. **Android Studio** o el SDK de Android instalado
3. **Java 11 o superior**

---

## Pasos para generar el APK

### 1. Copia la carpeta del proyecto
Extrae este ZIP en una carpeta de tu computador, por ejemplo:
```
C:\proyectos\neuroplan_ai\   (Windows)
~/proyectos/neuroplan_ai/    (Mac/Linux)
```

### 2. Abre una terminal en esa carpeta y ejecuta:
```bash
flutter pub get
```
Esto descarga todas las dependencias automáticamente.

### 3. Compila el APK:
```bash
flutter build apk --release
```

### 4. El APK estará en:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Instalar en tu celular Android

1. Activa **Fuentes desconocidas** en tu Android:
   - Ajustes → Seguridad → Instalar apps desconocidas → activar
2. Pasa el APK a tu celular (USB, WhatsApp, Google Drive, etc.)
3. Toca el archivo y presiona **Instalar**

---

## Configurar la IA (IMPORTANTE)

Al abrir la app, ve a la pestaña **Perfil** e ingresa tu API key de Gemini:
- Ve a https://aistudio.google.com/app/apikey
- Crea una API key gratuita
- Pégala en la app → Perfil → API Key de Gemini → Guardar

Sin la API key, la app funciona pero el chat con IA no estará activo.

---

## Estructura del proyecto

```
lib/
  main.dart              ← Punto de entrada, navegación
  models/
    chat_message.dart    ← Modelo de mensajes
    task.dart            ← Modelo de tareas
  services/
    gemini_service.dart  ← Integración con Gemini AI
    task_service.dart    ← Persistencia de tareas
  screens/
    chat_screen.dart     ← Pantalla principal de chat
    tasks_screen.dart    ← Gestión de tareas
    agenda_screen.dart   ← Calendario semanal
    profile_screen.dart  ← Configuración y API key
```

---

Desarrollado por Rodrigo Luis Villadiego Acevedo — NEUROPLAN AI v1.0.0
