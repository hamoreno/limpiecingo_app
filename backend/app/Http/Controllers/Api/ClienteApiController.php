<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cita;
use App\Models\Lavador;
use App\Models\Servicio;
use App\Models\Vehiculo;
use App\Notifications\SistemaNotificacion;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ClienteApiController extends Controller
{
    use ApiSupport;

    private function cliente(Request $request)
    {
        return $request->user()->cliente;
    }

    private function miCita(Request $request, $id): ?Cita
    {
        $cliente = $this->cliente($request);

        return $cliente ? Cita::where('cliente_id', $cliente->id)->where('id', $id)->first() : null;
    }

    // ---------------- Vehículos ----------------

    private function vehiculoArr(Vehiculo $v): array
    {
        return $v->only(['id', 'placa', 'marca', 'modelo', 'tipo', 'color']);
    }

    public function vehiculos(Request $request)
    {
        $cliente = $this->cliente($request);
        if (!$cliente) {
            return $this->fail('Tu usuario no tiene perfil de cliente.', 403);
        }

        return $this->ok(
            Vehiculo::where('cliente_id', $cliente->id)->orderBy('placa')->get()
                ->map(fn ($v) => $this->vehiculoArr($v))
        );
    }

    private function reglasVehiculo(?int $ignorarId = null): array
    {
        return [
            'placa' => ['required', 'string', 'max:30', Rule::unique('vehiculos', 'placa')->ignore($ignorarId)],
            'marca' => ['required', 'string', 'max:255'],
            'modelo' => ['nullable', 'string', 'max:255'],
            'tipo' => ['required', Rule::in(['Auto', 'Camioneta', 'Vagoneta', 'Moto', 'Camión'])],
            'color' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function crearVehiculo(Request $request)
    {
        $cliente = $this->cliente($request);
        if (!$cliente) {
            return $this->fail('Tu usuario no tiene perfil de cliente.', 403);
        }

        $request->merge(['placa' => strtoupper(trim((string) $request->placa))]);
        $d = $request->validate($this->reglasVehiculo());

        $v = Vehiculo::create($d + ['cliente_id' => $cliente->id]);

        return $this->ok($this->vehiculoArr($v), 'Vehículo registrado.', 201);
    }

    public function actualizarVehiculo(Request $request, $id)
    {
        $cliente = $this->cliente($request);
        $v = $cliente ? Vehiculo::where('cliente_id', $cliente->id)->find($id) : null;
        if (!$v) {
            return $this->fail('Vehículo no encontrado.', 404);
        }

        $request->merge(['placa' => strtoupper(trim((string) $request->placa))]);
        $v->update($request->validate($this->reglasVehiculo($v->id)));

        return $this->ok($this->vehiculoArr($v->fresh()), 'Vehículo actualizado.');
    }

    public function eliminarVehiculo(Request $request, $id)
    {
        $cliente = $this->cliente($request);
        $v = $cliente ? Vehiculo::where('cliente_id', $cliente->id)->find($id) : null;
        if (!$v) {
            return $this->fail('Vehículo no encontrado.', 404);
        }

        $enUso = Cita::where('vehiculo_id', $v->id)
            ->whereIn('estado', ['Pendiente', 'Aceptada', 'En camino', 'En proceso'])->exists();
        if ($enUso) {
            return $this->fail('No puedes eliminar un vehículo con citas activas.', 409);
        }

        $v->delete();

        return $this->ok(null, 'Vehículo eliminado.');
    }

    // ---------------- Citas ----------------

    public function citas(Request $request)
    {
        $cliente = $this->cliente($request);
        if (!$cliente) {
            return $this->fail('Tu usuario no tiene perfil de cliente.', 403);
        }

        $citas = Cita::with(['vehiculo', 'servicio', 'lavador'])
            ->where('cliente_id', $cliente->id)
            ->orderByDesc('fecha')->orderByDesc('hora')
            ->get()
            ->map(fn ($c) => $this->citaToArray($c));

        return $this->ok($citas);
    }

    public function cita(Request $request, $id)
    {
        $c = $this->miCita($request, $id);

        return $c ? $this->ok($this->citaToArray($c)) : $this->fail('Cita no encontrada.', 404);
    }

    public function crearCita(Request $request)
    {
        $cliente = $this->cliente($request);
        if (!$cliente) {
            return $this->fail('Tu usuario no tiene perfil de cliente.', 403);
        }

        $d = $request->validate([
            'vehiculo_id' => ['required', Rule::exists('vehiculos', 'id')->where('cliente_id', $cliente->id)],
            'servicio_id' => ['required', Rule::exists('servicios', 'id')->where('activo', true)],
            'fecha' => ['required', 'date', 'after_or_equal:today'],
            'hora' => ['required'],
            'direccion' => ['nullable', 'string', 'max:255'],
            'latitud' => ['nullable', 'required_without:direccion', 'numeric'],
            'longitud' => ['nullable', 'required_without:direccion', 'numeric'],
            'observacion_cliente' => ['nullable', 'string', 'max:1000'],
        ]);

        $existe = Cita::where('cliente_id', $cliente->id)
            ->where('vehiculo_id', $d['vehiculo_id'])
            ->whereDate('fecha', $d['fecha'])
            ->where('hora', $d['hora'])
            ->whereIn('estado', ['Pendiente', 'Aceptada', 'En camino', 'En proceso'])
            ->exists();

        if ($existe) {
            return $this->fail('Ya tienes una cita activa para este vehículo en esa fecha y hora.', 422);
        }

        $servicio = Servicio::findOrFail($d['servicio_id']);
        $precio = $servicio->precio ?? 0;
        $direccion = trim((string) ($d['direccion'] ?? '')) ?: 'Ubicación actual seleccionada por GPS';

        $cita = Cita::create([
            'cliente_id' => $cliente->id,
            'vehiculo_id' => $d['vehiculo_id'],
            'servicio_id' => $d['servicio_id'],
            'fecha' => $d['fecha'],
            'hora' => $d['hora'],
            'direccion' => $direccion,
            'latitud' => $d['latitud'] ?? null,
            'longitud' => $d['longitud'] ?? null,
            'estado' => 'Pendiente',
            'precio_total' => $precio,
            'ganancia_lavador' => $precio * 0.60,
            'ganancia_empresa' => $precio * 0.40,
            'estado_pago' => 'Pendiente',
            'encuesta_respondida' => false,
            'observacion_cliente' => $d['observacion_cliente'] ?? null,
        ]);

        $cita->load(['vehiculo', 'servicio']);

        $this->notificarAdmins(
            'Nueva solicitud de lavado',
            'El cliente ' . $cliente->nombre . ' ' . $cliente->apellido . ' solicitó un lavado para el vehículo ' . $cita->vehiculo?->placa . '.',
            route('admin.citas.show', $cita)
        );

        Lavador::with('user')
            ->where('estado_aprobacion', 'Aprobado')
            ->where('estado_disponibilidad', 'Disponible')
            ->get()
            ->each(function ($l) use ($direccion) {
                $l->user?->notify(new SistemaNotificacion(
                    'Nueva solicitud disponible',
                    'Hay una nueva solicitud de lavado en: ' . $direccion,
                    route('lavador.solicitudes.index')
                ));
            });

        return $this->ok($this->citaToArray($cita), 'Tu solicitud de lavado fue registrada correctamente.', 201);
    }

    public function cancelar(Request $request, $id)
    {
        $c = $this->miCita($request, $id);
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if ($c->estado !== 'Pendiente') {
            return $this->fail('Solo puedes cancelar citas pendientes.', 409);
        }

        $c->update(['estado' => 'Cancelada']);
        $this->notificarAdmins('Cita cancelada', 'Un cliente canceló su solicitud #' . $c->id . '.', route('admin.citas.show', $c), 'warning');

        return $this->ok($this->citaToArray($c->fresh()), 'Cita cancelada.');
    }

    public function pagar(Request $request, $id)
    {
        $c = $this->miCita($request, $id);
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if ($c->estado !== 'Finalizada') {
            return $this->fail('Solo puedes pagar una cita finalizada.', 409);
        }
        if ($c->estado_pago === 'Pagado') {
            return $this->fail('Esta cita ya fue marcada como pagada.', 409);
        }
        if ($c->estado_pago === 'En revisión') {
            return $this->fail('Tu pago ya está en revisión.', 409);
        }

        $d = $request->validate([
            'metodo_pago' => ['required', Rule::in(['Transferencia bancaria', 'QR'])],
            'comprobante_pago' => ['required', 'file', 'mimes:jpg,jpeg,png,webp,pdf', 'max:8192'],
            'observacion_pago' => ['nullable', 'string', 'max:1000'],
        ]);

        $ruta = $request->file('comprobante_pago')->store('pagos/comprobantes', 'public');

        $c->update([
            'metodo_pago' => $d['metodo_pago'],
            'estado_pago' => 'En revisión',
            'comprobante_pago' => $ruta,
            'observacion_pago' => $d['observacion_pago'] ?? null,
            'pagado_at' => now(),
        ]);

        $cli = $this->cliente($request);
        $this->notificarAdmins(
            'Pago enviado por cliente',
            'El cliente ' . $cli->nombre . ' ' . $cli->apellido . ' envió comprobante de pago por Bs ' . number_format($c->precio_total, 2) . '.',
            route('admin.citas.show', $c)
        );

        return $this->ok($this->citaToArray($c->fresh()), 'Comprobante enviado. Tu pago está en revisión.');
    }

    public function encuesta(Request $request, $id)
    {
        $c = $this->miCita($request, $id);
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if ($c->estado !== 'Finalizada' || $c->estado_pago !== 'Pagado') {
            return $this->fail('La encuesta se habilita cuando el pago está confirmado.', 409);
        }
        if ($c->encuesta_respondida) {
            return $this->fail('Ya respondiste la encuesta.', 409);
        }

        $d = $request->validate([
            'calificacion' => ['required', 'integer', 'min:1', 'max:5'],
            'comentario' => ['nullable', 'string', 'max:1000'],
        ]);

        $c->update([
            'encuesta_respondida' => true,
            'encuesta_calificacion' => $d['calificacion'],
            'encuesta_comentario' => $d['comentario'] ?? null,
            'encuesta_respondida_at' => now(),
        ]);

        return $this->ok($this->citaToArray($c->fresh()), '¡Gracias por tu calificación!');
    }

    public function ubicacionLavador(Request $request, $id)
    {
        $c = $this->miCita($request, $id);
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }

        $l = $c->lavador;
        if (!$l) {
            return $this->fail('Todavía no hay lavador asignado.', 404);
        }
        if (!$l->latitud_actual || !$l->longitud_actual) {
            return $this->fail('El lavador todavía no compartió su ubicación.', 404);
        }

        return $this->ok([
            'nombre' => $l->nombre . ' ' . $l->apellido,
            'telefono' => $l->telefono,
            'latitud' => (float) $l->latitud_actual,
            'longitud' => (float) $l->longitud_actual,
            'ultima_ubicacion_at' => optional($l->ultima_ubicacion_at)->toIso8601String(),
            'estado_cita' => $c->estado,
        ]);
    }
}
