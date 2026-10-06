<?php

namespace App\Http\Controllers\Api;

use App\Models\Cita;
use App\Models\User;
use App\Notifications\SistemaNotificacion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

/**
 * Helpers compartidos por los controladores de la API móvil.
 */
trait ApiSupport
{
    protected function ok(mixed $data = null, string $message = '', int $code = 200): JsonResponse
    {
        return response()->json(['status' => true, 'message' => $message, 'data' => $data], $code);
    }

    protected function fail(string $message, int $code = 422, array $errors = []): JsonResponse
    {
        return response()->json(['status' => false, 'message' => $message, 'errors' => $errors], $code);
    }

    protected function fileUrl(?string $path): ?string
    {
        return $path ? Storage::disk('public')->url($path) : null;
    }

    protected function notificarAdmins(string $titulo, string $mensaje, ?string $url = null, string $tipo = 'info'): void
    {
        foreach (User::role('Administrador')->get() as $admin) {
            $admin->notify(new SistemaNotificacion($titulo, $mensaje, $url, $tipo));
        }
    }

    /** Estructura estándar de una cita para la app. */
    protected function citaToArray(Cita $c): array
    {
        $c->loadMissing(['cliente', 'vehiculo', 'servicio', 'lavador']);
        $s = $c->servicio;

        return [
            'id' => $c->id,
            'fecha' => optional($c->fecha)->format('Y-m-d'),
            'hora' => substr((string) $c->hora, 0, 5),
            'direccion' => $c->direccion,
            'latitud' => $c->latitud !== null ? (float) $c->latitud : null,
            'longitud' => $c->longitud !== null ? (float) $c->longitud : null,
            'estado' => $c->estado,
            'precio_total' => (float) ($c->precio_total ?? $s?->precio ?? 0),
            'ganancia_lavador' => (float) ($c->ganancia_lavador ?? 0),
            'observacion_cliente' => $c->observacion_cliente,
            'metodo_pago' => $c->metodo_pago,
            'estado_pago' => $c->estado_pago,
            'observacion_pago' => $c->observacion_pago,
            'comprobante_url' => $this->fileUrl($c->comprobante_pago),
            'encuesta_respondida' => (bool) $c->encuesta_respondida,
            'encuesta_calificacion' => $c->encuesta_calificacion,
            'puede_cancelar' => $c->estado === 'Pendiente',
            'puede_pagar' => $c->estado === 'Finalizada'
                && in_array($c->estado_pago, ['Pendiente', 'Observado', null], true),
            'puede_evaluar' => $c->estado === 'Finalizada'
                && $c->estado_pago === 'Pagado'
                && !$c->encuesta_respondida,
            'cliente' => $c->cliente ? [
                'nombre' => $c->cliente->nombre . ' ' . $c->cliente->apellido,
                'telefono' => $c->cliente->telefono,
            ] : null,
            'vehiculo' => $c->vehiculo ? [
                'id' => $c->vehiculo->id,
                'placa' => $c->vehiculo->placa,
                'marca' => $c->vehiculo->marca,
                'modelo' => $c->vehiculo->modelo,
                'tipo' => $c->vehiculo->tipo,
                'color' => $c->vehiculo->color,
            ] : null,
            'servicio' => $s ? [
                'id' => $s->id,
                'nombre' => $s->nombre,
                'precio' => (float) $s->precio,
                'duracion_minutos' => $s->duracion_minutos,
                'banco' => $s->banco_transferencia ?? $s->banco,
                'numero_cuenta' => $s->numero_cuenta_transferencia ?? $s->numero_cuenta,
                'titular_cuenta' => $s->titular_cuenta_transferencia ?? $s->titular_cuenta,
                'qr_pago_url' => $this->fileUrl($s->qr_pago),
            ] : null,
            'lavador' => $c->lavador ? [
                'nombre' => $c->lavador->nombre . ' ' . $c->lavador->apellido,
                'telefono' => $c->lavador->telefono,
                'medio_transporte' => $c->lavador->medio_transporte,
            ] : null,
        ];
    }
}
