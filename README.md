# Limpiecingo — App móvil (Flutter) + API Laravel

Contenido del paquete:

```
backend/            -> archivos para COPIAR dentro de tu proyecto Laravel
limpiecingo_app/    -> código Flutter (lib/, pubspec.yaml, android_config/)
```

## PARTE 1 — Backend (Laravel)

1. Haz una copia de seguridad de `routes/api.php` y de `app/Http/Controllers/Api/`.
2. Copia el contenido de `backend/` sobre tu proyecto (respeta las rutas). Reemplaza:
   - `routes/api.php`
   - `app/Http/Controllers/Api/AuthApiController.php`
   - `app/Http/Controllers/Api/ServiceApiController.php`
   y agrega: `ApiSupport.php`, `ClienteApiController.php`, `LavadorApiController.php`, `NotificacionApiController.php`.
3. En la terminal del proyecto Laravel:
   ```
   php artisan storage:link        # para que las imágenes/comprobantes tengan URL pública
   php artisan route:list --path=api
   ```
4. En `.env` pon `APP_URL` con la URL que usará el celular (ej. `http://192.168.1.50:8000`),
   porque de ahí salen las URLs de comprobantes y QR.
5. Inicia el servidor accesible en la red:
   ```
   php artisan serve --host=0.0.0.0 --port=8000
   ```
   (Si usas XAMPP/Laragon, apunta a la URL de tu virtual host.)
6. Prueba en Postman: `POST /api/v1/login` con un cliente existente → debe devolver `token`.

### Endpoints (todos bajo /api/v1, Bearer token salvo login/register/servicios)
| Rol | Método y ruta |
|---|---|
| Público | `POST login`, `POST register`, `GET servicios` |
| Todos | `GET user`, `POST logout`, `GET notificaciones`, `GET notificaciones/contador`, `POST notificaciones/{id}/leer`, `POST notificaciones/leer-todas` |
| Cliente | `GET/POST cliente/vehiculos`, `PUT/DELETE cliente/vehiculos/{id}`, `GET/POST cliente/citas`, `GET cliente/citas/{id}`, `POST …/cancelar`, `POST …/pagar` (multipart), `POST …/encuesta`, `GET …/ubicacion-lavador` |
| Lavador | `GET lavador/perfil`, `POST lavador/conectar`, `POST lavador/desconectar`, `POST lavador/ubicacion`, `GET lavador/solicitudes`, `POST lavador/solicitudes/{id}/aceptar`, `GET lavador/citas?tipo=activas|historial`, `GET lavador/citas/{id}`, `POST …/en-camino`, `POST …/en-proceso`, `POST …/finalizar`, `GET lavador/ganancias` |
| IA | `POST /api/ai/chat` (fuera de v1) |

Las reglas son las mismas que en tu web (misma comisión, estados, choque de horarios, flujo de pago y notificaciones),
así que web y móvil comparten la misma base de datos y se ven los mismos datos.

## PARTE 2 — Proyecto Flutter en Android Studio

Requisitos: Flutter SDK 3.27 o superior, Android Studio con plugins Flutter y Dart, un emulador o un celular con depuración USB.

1. Crea el proyecto base:
   ```
   flutter create --org com.limpiecingo --project-name limpiecingo_app limpiecingo_app
   ```
   (o en Android Studio: File > New > New Flutter Project, nombre `limpiecingo_app`).
2. Sustituye `pubspec.yaml` y la carpeta `lib/` por las de este paquete. Borra `test/widget_test.dart` si da error.
3. Aplica los cambios de `android_config/AndroidManifest_cambios.txt` en `android/app/src/main/AndroidManifest.xml`.
4. En `android/app/build.gradle(.kts)` verifica `minSdk` ≥ 21 (geolocator/secure storage; si pide, usa `minSdk = 23`).
5. Edita `lib/core/config.dart` y pon la URL de tu servidor:
   - Emulador: `http://10.0.2.2:8000`
   - Celular físico: `http://IP_DE_TU_PC:8000` (misma WiFi, firewall permitiendo el puerto)
6. Ejecuta:
   ```
   flutter pub get
   flutter run
   ```

## Qué hace la app
- **Cliente:** registro/login, vehículos (CRUD), solicitar lavado (servicio, vehículo, fecha/hora, GPS o mapa),
  seguimiento con mapa y ubicación del lavador en vivo, pago con comprobante (transferencia/QR),
  calificación, notificaciones y chat con Cingo.
- **Lavador:** registro con documentos, conectarse/desconectarse, solicitudes pendientes, aceptar,
  En camino → En proceso → Finalizar, navegación a Google Maps, ganancias, envío de GPS cada 15 s.

## Limitaciones conocidas (para una siguiente fase)
- El GPS del lavador se envía **solo con la app abierta** (foreground). Para segundo plano hace falta un servicio en primer plano (`flutter_background_service` o `geolocator` con foreground notification).
- Las notificaciones son **dentro de la app** (se leen de la base de datos). Notificaciones push reales requieren Firebase Cloud Messaging.
- Los mapas usan OpenStreetMap (sin API key). Para uso comercial intensivo conviene un proveedor de tiles propio.
- No hay "olvidé mi contraseña" ni edición de perfil en la app (existen en la web).
- El chat de IA depende de que Ollama esté activo en el servidor.
- Seguridad pendiente en backend: `/api/ai/chat` es público (ya tiene límite de 30 peticiones/min).
