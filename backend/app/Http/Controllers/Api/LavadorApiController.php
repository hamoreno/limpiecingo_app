<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cita;
use App\Models\Lavado;
use App\Models\Lavador;
use App\Models\User;
use App\Notifications\SistemaNotificacion;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LavadorApiController extends Controller
{
    use ApiSupport;

    private const ACTIVOS = ['Aceptada', 'En camino', 'En proceso'];

    private function lavador(Request $request): ?Lavador
    {
        return $request->user()->lavador;
    }

    private function miCita(Lavador $l, $id): ?Cita
    {
        return Cita::where('lavador_id', $l->id)->where('id', $id)->first();
    }

    private function perfilArr(Lavador $l): array
    {
        return [
            'nombre' => $l->nombre,
            'apellido' => $l->apellido,
            'telefono' => $l->telefono,
            'medio_transporte' => $l->medio_transporte,
            'foto_perfil_url' => $this->fileUrl($l->foto_perfil),
            'estado_aprobacion' => $l->estado_aprobacion,
            'estado_disponibilidad' => $l->estado_disponibilidad,
            'porcentaje_ganancia' => (float) $l->porcentaje_ganancia,
            'puede_conectarse' => $l->estado_aprobacion === 'Aprobado' && $l->estado_disponibilidad === 'Desconectado',
            'puede_desconectarse' => $l->estado_aprobacion === 'Aprobado' && $l->estado_disponibilidad === 'Disponible',
        ];
    }

    public function perfil(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }

        $hoy = today()->toDateString();
        $data = $this->perfilArr($l) + [
            'citas_hoy' => Cita::where('lavador_id', $l->id)->whereDate('fecha', $hoy)->whereIn('estado', self::ACTIVOS)->count(),
            'ganancia_hoy' => (float) Lavado::where('lavador_id', $l->id)->whereDate('finalizado_at', $hoy)->sum('ganancia_lavador'),
        ];

        return $this->ok($data);
    }

    public function conectar(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }
        if ($l->estado_aprobacion !== 'Aprobado') {
            return $this->fail('Tu cuenta aún no fue aprobada por el administrador.', 403);
        }
        if ($l->estado_disponibilidad !== 'Desconectado') {
            return $this->fail('Solo puedes conectarte si estás desconectado.', 409);
        }

        $l->update(['estado_disponibilidad' => 'Disponible']);

        return $this->ok($this->perfilArr($l->fresh()), 'Ahora estás conectado.');
    }

    public function desconectar(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }
        if ($l->estado_disponibilidad !== 'Disponible') {
            return $this->fail('Solo puedes desconectarte si estás disponible (sin servicio en curso).', 409);
        }

        $l->update(['estado_disponibilidad' => 'Desconectado']);

        return $this->ok($this->perfilArr($l->fresh()), 'Te desconectaste.');
    }

    public function ubicacion(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l || $l->estado_aprobacion !== 'Aprobado') {
            return $this->fail('Tu cuenta aún no fue aprobada.', 403);
        }

        $d = $request->validate([
            'latitud' => ['required', 'numeric', 'between:-90,90'],
            'longitud' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $l->update([
            'latitud_actual' => $d['latitud'],
            'longitud_actual' => $d['longitud'],
            'ultima_ubicacion_at' => now(),
        ]);

        return $this->ok(null, 'Ubicación actualizada.');
    }

    // ---------------- Solicitudes ----------------

    public function solicitudes(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }
        if ($l->estado_aprobacion !== 'Aprobado') {
            return $this->fail('Tu cuenta aún no fue aprobada por el administrador.', 403);
        }

        $citas = Cita::with(['cliente', 'vehiculo', 'servicio'])
            ->where('estado', 'Pendiente')
            ->whereNull('lavador_id')
            ->whereDate('fecha', '>=', today())
            ->orderBy('fecha')->orderBy('hora')
            ->get()
            ->map(fn ($c) => $this->citaToArray($c));

        return $this->ok($citas);
    }

    public function aceptar(Request $request, $id)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }
        if ($l->estado_aprobacion !== 'Aprobado') {
            return $this->fail('Tu cuenta aún no fue aprobada por el administrador.', 403);
        }
        if ($l->estado_disponibilidad !== 'Disponible') {
            return $this->fail('Solo puedes aceptar solicitudes cuando estás conectado y disponible.', 409);
        }

        $cita = Cita::with('servicio')->find($id);
        if (!$cita) {
            return $this->fail('Solicitud no encontrada.', 404);
        }
        if ($this->tieneChoqueHorario($l, $cita)) {
            return $this->fail('Esta solicitud choca con otra cita que ya tienes en el mismo horario.', 409);
        }

        $aceptada = false;
        DB::transaction(function () use ($cita, $l, &$aceptada) {
            $b = Cita::where('id', $cita->id)->lockForUpdate()->firstOrFail();
            if ($b->estado !== 'Pendiente' || $b->lavador_id !== null) {
                return;
            }
            $b->update(['lavador_id' => $l->id, 'estado' => 'Aceptada']);
            $aceptada = true;
        });

        if (!$aceptada) {
            return $this->fail('Esta solicitud ya fue tomada por otro lavador o ya no está pendiente.', 409);
        }

        $cita->refresh()->load(['cliente.user', 'vehiculo', 'servicio', 'lavador']);

        $cita->cliente?->user?->notify(new SistemaNotificacion(
            'Tu cita fue aceptada',
            'El lavador ' . $l->nombre . ' ' . $l->apellido . ' aceptó tu solicitud de lavado.',
            route('cliente.citas.show', $cita),
            'success'
        ));
        $this->notificarAdmins('Solicitud aceptada', 'El lavador ' . $l->nombre . ' ' . $l->apellido . ' aceptó una solicitud de lavado.', route('admin.citas.show', $cita));

        return $this->ok($this->citaToArray($cita), 'Solicitud aceptada correctamente.');
    }

    // ---------------- Mis citas ----------------

    public function citas(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }

        $q = Cita::with(['cliente', 'vehiculo', 'servicio'])->where('lavador_id', $l->id);

        if ($request->query('tipo') === 'activas') {
            $q->whereIn('estado', self::ACTIVOS);
        } elseif ($request->query('tipo') === 'historial') {
            $q->whereIn('estado', ['Finalizada', 'Cancelada']);
        }

        $citas = $q->orderByDesc('fecha')->orderByDesc('hora')->get()->map(fn ($c) => $this->citaToArray($c));

        return $this->ok($citas);
    }

    public function cita(Request $request, $id)
    {
        $l = $this->lavador($request);
        $c = $l ? $this->miCita($l, $id) : null;

        return $c ? $this->ok($this->citaToArray($c)) : $this->fail('Cita no encontrada.', 404);
    }

    public function enCamino(Request $request, $id)
    {
        $l = $this->lavador($request);
        $c = $l ? $this->miCita($l, $id) : null;
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if ($c->estado !== 'Aceptada') {
            return $this->fail('Solo puedes marcar En camino una cita aceptada.', 409);
        }

        $c->update(['estado' => 'En camino']);
        $l->update(['estado_disponibilidad' => 'Ocupado']);

        $c->load('cliente.user');
        $c->cliente?->user?->notify(new SistemaNotificacion(
            'Tu lavador está en camino',
            'El lavador ' . $l->nombre . ' ' . $l->apellido . ' ya está en camino hacia tu ubicación.',
            route('cliente.citas.show', $c)
        ));

        return $this->ok($this->citaToArray($c), 'Estado actualizado a En camino.');
    }

    public function enProceso(Request $request, $id)
    {
        $l = $this->lavador($request);
        $c = $l ? $this->miCita($l, $id) : null;
        if (!$c) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if ($c->estado !== 'En camino') {
            return $this->fail('Solo puedes iniciar el lavado cuando estás En camino.', 409);
        }

        $c->update(['estado' => 'En proceso']);

        $c->load('cliente.user');
        $c->cliente?->user?->notify(new SistemaNotificacion(
            'Lavado en proceso',
            'El lavador ' . $l->nombre . ' ' . $l->apellido . ' comenzó el lavado de tu vehículo.',
            route('cliente.citas.show', $c)
        ));

        return $this->ok($this->citaToArray($c), 'Estado actualizado a En proceso.');
    }

    public function finalizar(Request $request, $id)
    {
        $l = $this->lavador($request);
        $cita = $l ? $this->miCita($l, $id) : null;
        if (!$cita) {
            return $this->fail('Cita no encontrada.', 404);
        }
        if (!in_array($cita->estado, self::ACTIVOS, true)) {
            return $this->fail('Esta cita no puede finalizarse en su estado actual.', 409);
        }

        $cita->load(['servicio', 'cliente.user']);
        if (!$cita->servicio) {
            return $this->fail('Esta cita no tiene un servicio asociado.', 409);
        }

        $request->validate(['observacion_lavador' => ['nullable', 'string', 'max:1000']]);

        $pct = $l->porcentaje_ganancia ?? 60;
        $precio = $cita->servicio->precio ?? 0;
        $gLav = $precio * ($pct / 100);
        $gEmp = $precio - $gLav;

        DB::transaction(function () use ($cita, $l, $precio, $gLav, $gEmp, $request) {
            $cita->update([
                'estado' => 'Finalizada',
                'precio_total' => $precio,
                'ganancia_lavador' => $gLav,
                'ganancia_empresa' => $gEmp,
                'estado_pago' => 'Pendiente',
                'metodo_pago' => null,
                'comprobante_pago' => null,
                'observacion_pago' => null,
                'pagado_at' => null,
                'observacion_lavador' => $request->input('observacion_lavador'),
            ]);

            Lavado::updateOrCreate(['cita_id' => $cita->id], [
                'cliente_id' => $cita->cliente_id,
                'lavador_id' => $l->id,
                'servicio_id' => $cita->servicio_id,
                'precio_total' => $precio,
                'ganancia_lavador' => $gLav,
                'ganancia_empresa' => $gEmp,
                'finalizado_at' => now(),
            ]);

            $l->update(['estado_disponibilidad' => 'Disponible']);
        });

        $cita->cliente?->user?->notify(new SistemaNotificacion(
            'Lavado finalizado',
            'Tu lavado fue finalizado correctamente. Ya puedes realizar el pago del servicio.',
            route('cliente.citas.show', $cita),
            'success'
        ));
        $l->user?->notify(new SistemaNotificacion(
            'Ganancia registrada',
            'Se registró tu ganancia de Bs ' . number_format($gLav, 2) . ' por este servicio.',
            route('lavador.ganancias.index'),
            'success'
        ));
        $this->notificarAdmins(
            'Lavado finalizado',
            'Se finalizó un lavado. Ganancia empresa: Bs ' . number_format($gEmp, 2) . '. El pago del cliente queda pendiente.',
            route('admin.lavados.index'),
            'success'
        );

        return $this->ok($this->citaToArray($cita->fresh()), 'Lavado finalizado correctamente.');
    }

    public function ganancias(Request $request)
    {
        $l = $this->lavador($request);
        if (!$l) {
            return $this->fail('Tu usuario no tiene perfil de lavador.', 403);
        }

        $base = fn () => Lavado::where('lavador_id', $l->id);

        $ultimos = $base()->with(['servicio', 'cliente'])->latest('finalizado_at')->limit(30)->get()->map(fn ($x) => [
            'cita_id' => $x->cita_id,
            'servicio' => $x->servicio?->nombre,
            'cliente' => $x->cliente ? $x->cliente->nombre . ' ' . $x->cliente->apellido : null,
            'precio_total' => (float) $x->precio_total,
            'ganancia_lavador' => (float) $x->ganancia_lavador,
            'finalizado_at' => optional($x->finalizado_at)->toIso8601String(),
        ]);

        return $this->ok([
            'hoy' => (float) $base()->whereDate('finalizado_at', today())->sum('ganancia_lavador'),
            'semana' => (float) $base()->where('finalizado_at', '>=', now()->startOfWeek())->sum('ganancia_lavador'),
            'mes' => (float) $base()->where('finalizado_at', '>=', now()->startOfMonth())->sum('ganancia_lavador'),
            'total' => (float) $base()->sum('ganancia_lavador'),
            'servicios_realizados' => $base()->count(),
            'ultimos' => $ultimos,
        ]);
    }

    private function inicioCita(Cita $c): Carbon
    {
        return Carbon::parse(Carbon::parse($c->fecha)->toDateString() . ' ' . $c->hora);
    }

    private function tieneChoqueHorario(Lavador $l, Cita $nueva): bool
    {
        $ini = $this->inicioCita($nueva);
        $fin = $ini->copy()->addMinutes($nueva->servicio->duracion_minutos ?? 60);

        $activas = Cita::with('servicio')
            ->where('lavador_id', $l->id)
            ->whereIn('estado', self::ACTIVOS)
            ->whereDate('fecha', Carbon::parse($nueva->fecha)->toDateString())
            ->get();

        foreach ($activas as $a) {
            if ($a->id === $nueva->id) {
                continue;
            }
            $aIni = $this->inicioCita($a);
            $aFin = $aIni->copy()->addMinutes($a->servicio->duracion_minutos ?? 60);
            if ($ini->lt($aFin) && $fin->gt($aIni)) {
                return true;
            }
        }

        return false;
    }
}
