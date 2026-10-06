<?php

use App\Http\Controllers\AIChatController;
use App\Http\Controllers\Api\AuthApiController;
use App\Http\Controllers\Api\ClienteApiController;
use App\Http\Controllers\Api\LavadorApiController;
use App\Http\Controllers\Api\NotificacionApiController;
use App\Http\Controllers\Api\ServiceApiController;
use Illuminate\Support\Facades\Route;

Route::post('/ai/chat', [AIChatController::class, 'chat'])->middleware('throttle:30,1');

Route::prefix('v1')->group(function () {

    // ---------- Públicas ----------
    Route::post('/login', [AuthApiController::class, 'login'])->middleware('throttle:10,1');
    Route::post('/register', [AuthApiController::class, 'register'])->middleware('throttle:10,1');
    Route::get('/servicios', [ServiceApiController::class, 'index']);

    // ---------- Autenticadas ----------
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/user', [AuthApiController::class, 'user']);
        Route::post('/logout', [AuthApiController::class, 'logout']);

        // Notificaciones (todos los roles)
        Route::get('/notificaciones', [NotificacionApiController::class, 'index']);
        Route::get('/notificaciones/contador', [NotificacionApiController::class, 'contador']);
        Route::post('/notificaciones/leer-todas', [NotificacionApiController::class, 'leerTodas']);
        Route::post('/notificaciones/{id}/leer', [NotificacionApiController::class, 'leer']);

        // ---------- CLIENTE ----------
        Route::prefix('cliente')->middleware('role:Cliente')->group(function () {
            Route::get('/vehiculos', [ClienteApiController::class, 'vehiculos']);
            Route::post('/vehiculos', [ClienteApiController::class, 'crearVehiculo']);
            Route::put('/vehiculos/{id}', [ClienteApiController::class, 'actualizarVehiculo']);
            Route::delete('/vehiculos/{id}', [ClienteApiController::class, 'eliminarVehiculo']);

            Route::get('/citas', [ClienteApiController::class, 'citas']);
            Route::post('/citas', [ClienteApiController::class, 'crearCita']);
            Route::get('/citas/{id}', [ClienteApiController::class, 'cita']);
            Route::post('/citas/{id}/cancelar', [ClienteApiController::class, 'cancelar']);
            Route::post('/citas/{id}/pagar', [ClienteApiController::class, 'pagar']);
            Route::post('/citas/{id}/encuesta', [ClienteApiController::class, 'encuesta']);
            Route::get('/citas/{id}/ubicacion-lavador', [ClienteApiController::class, 'ubicacionLavador']);
        });

        // ---------- LAVADOR ----------
        Route::prefix('lavador')->middleware('role:Lavador')->group(function () {
            Route::get('/perfil', [LavadorApiController::class, 'perfil']);
            Route::post('/conectar', [LavadorApiController::class, 'conectar']);
            Route::post('/desconectar', [LavadorApiController::class, 'desconectar']);
            Route::post('/ubicacion', [LavadorApiController::class, 'ubicacion']);

            Route::get('/solicitudes', [LavadorApiController::class, 'solicitudes']);
            Route::post('/solicitudes/{id}/aceptar', [LavadorApiController::class, 'aceptar']);

            Route::get('/citas', [LavadorApiController::class, 'citas']);
            Route::get('/citas/{id}', [LavadorApiController::class, 'cita']);
            Route::post('/citas/{id}/en-camino', [LavadorApiController::class, 'enCamino']);
            Route::post('/citas/{id}/en-proceso', [LavadorApiController::class, 'enProceso']);
            Route::post('/citas/{id}/finalizar', [LavadorApiController::class, 'finalizar']);

            Route::get('/ganancias', [LavadorApiController::class, 'ganancias']);
        });
    });
});
