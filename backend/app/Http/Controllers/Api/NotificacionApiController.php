<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class NotificacionApiController extends Controller
{
    use ApiSupport;

    public function index(Request $request)
    {
        $items = $request->user()->notifications()->latest()->limit(50)->get()->map(fn ($n) => [
            'id' => $n->id,
            'titulo' => $n->data['titulo'] ?? '',
            'mensaje' => $n->data['mensaje'] ?? '',
            'tipo' => $n->data['tipo'] ?? 'info',
            'leida' => $n->read_at !== null,
            'fecha' => $n->created_at->toIso8601String(),
        ]);

        return $this->ok($items);
    }

    public function contador(Request $request)
    {
        return $this->ok(['no_leidas' => $request->user()->unreadNotifications()->count()]);
    }

    public function leer(Request $request, string $id)
    {
        $n = $request->user()->notifications()->where('id', $id)->first();
        if (!$n) {
            return $this->fail('Notificación no encontrada.', 404);
        }
        $n->markAsRead();

        return $this->ok(null, 'Marcada como leída.');
    }

    public function leerTodas(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();

        return $this->ok(null, 'Todas marcadas como leídas.');
    }
}
