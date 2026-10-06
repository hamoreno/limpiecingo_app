<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Servicio;

class ServiceApiController extends Controller
{
    use ApiSupport;

    public function index()
    {
        $servicios = Servicio::where('activo', true)
            ->orderBy('nombre')
            ->get()
            ->map(fn ($s) => [
                'id' => $s->id,
                'nombre' => $s->nombre,
                'descripcion' => $s->descripcion,
                'precio' => (float) $s->precio,
                'duracion_minutos' => $s->duracion_minutos,
            ]);

        return $this->ok($servicios);
    }
}
