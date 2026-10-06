double _d(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
double? _dn(dynamic v) => v == null ? null : double.tryParse(v.toString());

class AppUser {
  final int id;
  final String name;
  final String email;
  final String rol; // Cliente | Lavador
  final Map<String, dynamic> perfil;

  AppUser({required this.id, required this.name, required this.email, required this.rol, required this.perfil});

  bool get esCliente => rol == 'Cliente';
  bool get esLavador => rol == 'Lavador';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        rol: j['rol'] ?? '',
        perfil: Map<String, dynamic>.from(j['perfil'] ?? {}),
      );
}

class Servicio {
  final int id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int duracionMinutos;

  Servicio({required this.id, required this.nombre, this.descripcion, required this.precio, required this.duracionMinutos});

  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
        id: j['id'],
        nombre: j['nombre'] ?? '',
        descripcion: j['descripcion'],
        precio: _d(j['precio']),
        duracionMinutos: j['duracion_minutos'] ?? 60,
      );
}

class Vehiculo {
  final int id;
  final String placa;
  final String marca;
  final String? modelo;
  final String tipo;
  final String? color;

  Vehiculo({required this.id, required this.placa, required this.marca, this.modelo, required this.tipo, this.color});

  String get titulo => '$marca ${modelo ?? ''}'.trim();

  factory Vehiculo.fromJson(Map<String, dynamic> j) => Vehiculo(
        id: j['id'],
        placa: j['placa'] ?? '',
        marca: j['marca'] ?? '',
        modelo: j['modelo'],
        tipo: j['tipo'] ?? 'Auto',
        color: j['color'],
      );
}

class Cita {
  final int id;
  final String fecha;
  final String hora;
  final String direccion;
  final double? latitud;
  final double? longitud;
  final String estado;
  final double precioTotal;
  final double gananciaLavador;
  final String? observacionCliente;
  final String? metodoPago;
  final String? estadoPago;
  final String? observacionPago;
  final String? comprobanteUrl;
  final bool encuestaRespondida;
  final int? encuestaCalificacion;
  final bool puedeCancelar;
  final bool puedePagar;
  final bool puedeEvaluar;
  final bool tieneChoque;
  final Map<String, dynamic>? cliente;
  final Map<String, dynamic>? vehiculo;
  final Map<String, dynamic>? servicio;
  final Map<String, dynamic>? lavador;

  Cita({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.direccion,
    this.latitud,
    this.longitud,
    required this.estado,
    required this.precioTotal,
    required this.gananciaLavador,
    this.observacionCliente,
    this.metodoPago,
    this.estadoPago,
    this.observacionPago,
    this.comprobanteUrl,
    required this.encuestaRespondida,
    this.encuestaCalificacion,
    required this.puedeCancelar,
    required this.puedePagar,
    required this.puedeEvaluar,
    this.tieneChoque = false,
    this.cliente,
    this.vehiculo,
    this.servicio,
    this.lavador,
  });

  String get servicioNombre => servicio?['nombre'] ?? '-';
  String get vehiculoTexto => vehiculo == null
      ? '-'
      : '${vehiculo!['placa']} · ${vehiculo!['marca']} ${vehiculo!['modelo'] ?? ''}'.trim();
  bool get activa => ['Aceptada', 'En camino', 'En proceso'].contains(estado);
  bool get tieneUbicacion => latitud != null && longitud != null;

  factory Cita.fromJson(Map<String, dynamic> j) => Cita(
        id: j['id'],
        fecha: j['fecha'] ?? '',
        hora: j['hora'] ?? '',
        direccion: j['direccion'] ?? '',
        latitud: _dn(j['latitud']),
        longitud: _dn(j['longitud']),
        estado: j['estado'] ?? '',
        precioTotal: _d(j['precio_total']),
        gananciaLavador: _d(j['ganancia_lavador']),
        observacionCliente: j['observacion_cliente'],
        metodoPago: j['metodo_pago'],
        estadoPago: j['estado_pago'],
        observacionPago: j['observacion_pago'],
        comprobanteUrl: j['comprobante_url'],
        encuestaRespondida: j['encuesta_respondida'] == true,
        encuestaCalificacion: j['encuesta_calificacion'],
        puedeCancelar: j['puede_cancelar'] == true,
        puedePagar: j['puede_pagar'] == true,
        puedeEvaluar: j['puede_evaluar'] == true,
        tieneChoque: j['tiene_choque'] == true,
        cliente: j['cliente'] == null ? null : Map<String, dynamic>.from(j['cliente']),
        vehiculo: j['vehiculo'] == null ? null : Map<String, dynamic>.from(j['vehiculo']),
        servicio: j['servicio'] == null ? null : Map<String, dynamic>.from(j['servicio']),
        lavador: j['lavador'] == null ? null : Map<String, dynamic>.from(j['lavador']),
      );
}

class Notificacion {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final DateTime fecha;

  Notificacion({required this.id, required this.titulo, required this.mensaje, required this.tipo, required this.leida, required this.fecha});

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
        id: j['id'],
        titulo: j['titulo'] ?? '',
        mensaje: j['mensaje'] ?? '',
        tipo: j['tipo'] ?? 'info',
        leida: j['leida'] == true,
        fecha: DateTime.tryParse(j['fecha'] ?? '') ?? DateTime.now(),
      );
}

class Ganancias {
  final double hoy, semana, mes, total;
  final int servicios;
  final List<Map<String, dynamic>> ultimos;

  Ganancias({required this.hoy, required this.semana, required this.mes, required this.total, required this.servicios, required this.ultimos});

  factory Ganancias.fromJson(Map<String, dynamic> j) => Ganancias(
        hoy: _d(j['hoy']),
        semana: _d(j['semana']),
        mes: _d(j['mes']),
        total: _d(j['total']),
        servicios: j['servicios_realizados'] ?? 0,
        ultimos: List<Map<String, dynamic>>.from((j['ultimos'] ?? []).map((e) => Map<String, dynamic>.from(e))),
      );
}
