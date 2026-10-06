<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cliente;
use App\Models\Lavador;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AuthApiController extends Controller
{
    use ApiSupport;

    private function userPayload(User $user): array
    {
        $rol = $user->getRoleNames()->first();
        $payload = [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'activo' => (bool) $user->activo,
            'roles' => $user->getRoleNames(),
            'rol' => $rol,
        ];

        if ($user->cliente) {
            $payload['perfil'] = [
                'nombre' => $user->cliente->nombre,
                'apellido' => $user->cliente->apellido,
                'telefono' => $user->cliente->telefono,
                'direccion' => $user->cliente->direccion,
            ];
        }

        if ($user->lavador) {
            $l = $user->lavador;
            $payload['perfil'] = [
                'nombre' => $l->nombre,
                'apellido' => $l->apellido,
                'telefono' => $l->telefono,
                'estado_aprobacion' => $l->estado_aprobacion,
                'estado_disponibilidad' => $l->estado_disponibilidad,
            ];
        }

        return $payload;
    }

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        $user = User::where('email', strtolower(trim($request->email)))->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return $this->fail('Credenciales incorrectas.', 401);
        }

        if (!$user->activo) {
            return $this->fail('Tu usuario está inactivo. Comunícate con el administrador.', 403);
        }

        if (!$user->hasAnyRole(['Cliente', 'Lavador'])) {
            return $this->fail('Esta app es solo para clientes y lavadores. Usa el panel web.', 403);
        }

        // Una sola sesión móvil activa
        $user->tokens()->delete();
        $token = $user->createToken('limpiecingo_mobile_token')->plainTextToken;

        return response()->json([
            'status' => true,
            'message' => 'Inicio de sesión correcto.',
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => $this->userPayload($user),
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        $esLavador = $request->tipo_registro === 'Lavador';

        $reglas = [
            'tipo_registro' => ['required', Rule::in(['Cliente', 'Lavador'])],
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'confirmed', Password::min(8)],
            'nombre' => ['required', 'string', 'max:255'],
            'apellido' => ['required', 'string', 'max:255'],
            'ci' => ['required', 'string', 'max:255', Rule::unique('clientes', 'ci'), Rule::unique('lavadores', 'ci')],
            'telefono' => ['required', 'string', 'max:255'],
            'direccion' => ['nullable', 'string', 'max:255'],
        ];

        if ($esLavador) {
            $reglas += [
                'fecha_nacimiento' => ['required', 'date', 'before:-18 years'],
                'medio_transporte' => ['required', 'string', 'max:255'],
                'licencia_numero' => ['required', 'string', 'max:255', Rule::unique('lavadores', 'licencia_numero')],
                'licencia_categoria' => ['required', 'string', 'max:50'],
                'licencia_vencimiento' => ['required', 'date', 'after:today'],
                'banco' => ['nullable', 'string', 'max:255'],
                'numero_cuenta' => ['nullable', 'string', 'max:255'],
                'titular_cuenta' => ['nullable', 'string', 'max:255'],
                'contacto_emergencia' => ['required', 'string', 'max:255'],
                'telefono_emergencia' => ['required', 'string', 'max:255'],
                'foto_perfil' => ['nullable', 'image', 'max:5120'],
                'foto_licencia' => ['nullable', 'image', 'max:5120'],
                'foto_ci_anverso' => ['nullable', 'image', 'max:5120'],
                'foto_ci_reverso' => ['nullable', 'image', 'max:5120'],
            ];
        }

        $d = $request->validate($reglas);

        $user = DB::transaction(function () use ($d, $request, $esLavador) {
            $user = User::create([
                'name' => trim($d['name']),
                'email' => strtolower(trim($d['email'])),
                'password' => $d['password'],
                'activo' => true,
            ]);

            if (!$esLavador) {
                $user->assignRole('Cliente');
                Cliente::create([
                    'user_id' => $user->id,
                    'nombre' => $d['nombre'],
                    'apellido' => $d['apellido'],
                    'ci' => $d['ci'],
                    'telefono' => $d['telefono'],
                    'direccion' => $d['direccion'] ?? null,
                ]);

                return $user;
            }

            $user->assignRole('Lavador');
            $archivo = fn (string $campo, string $dir) => $request->hasFile($campo)
                ? $request->file($campo)->store($dir, 'public')
                : null;

            Lavador::create([
                'user_id' => $user->id,
                'nombre' => $d['nombre'],
                'apellido' => $d['apellido'],
                'ci' => $d['ci'],
                'telefono' => $d['telefono'],
                'direccion' => $d['direccion'] ?? null,
                'fecha_nacimiento' => $d['fecha_nacimiento'],
                'medio_transporte' => $d['medio_transporte'],
                'licencia_numero' => $d['licencia_numero'],
                'licencia_categoria' => $d['licencia_categoria'],
                'licencia_vencimiento' => $d['licencia_vencimiento'],
                'foto_perfil' => $archivo('foto_perfil', 'lavadores/perfiles'),
                'foto_licencia' => $archivo('foto_licencia', 'lavadores/licencias'),
                'foto_ci_anverso' => $archivo('foto_ci_anverso', 'lavadores/ci'),
                'foto_ci_reverso' => $archivo('foto_ci_reverso', 'lavadores/ci'),
                'banco' => $d['banco'] ?? null,
                'numero_cuenta' => $d['numero_cuenta'] ?? null,
                'titular_cuenta' => $d['titular_cuenta'] ?? null,
                'contacto_emergencia' => $d['contacto_emergencia'],
                'telefono_emergencia' => $d['telefono_emergencia'],
                'estado_aprobacion' => 'Pendiente',
                'estado_disponibilidad' => 'Desconectado',
                'porcentaje_ganancia' => 60,
            ]);

            return $user;
        });

        if ($esLavador) {
            $this->notificarAdmins(
                'Nuevo lavador por aprobar',
                'El lavador ' . $d['nombre'] . ' ' . $d['apellido'] . ' se registró desde la app y espera aprobación.',
                route('admin.lavadores.index'),
                'info'
            );
        }

        $token = $user->createToken('limpiecingo_mobile_token')->plainTextToken;

        return response()->json([
            'status' => true,
            'message' => $esLavador
                ? 'Registro enviado. Un administrador debe aprobar tu cuenta.'
                : 'Cuenta creada correctamente.',
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => $this->userPayload($user->fresh()),
        ], 201);
    }

    public function user(Request $request): JsonResponse
    {
        return response()->json([
            'status' => true,
            'user' => $this->userPayload($request->user()),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->ok(null, 'Sesión cerrada correctamente.');
    }
}
