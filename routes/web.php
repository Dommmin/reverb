<?php

use App\Http\Controllers\ClickController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::get('/', function () {
    return Inertia::render('welcome');
})->name('home');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('dashboard', function () {
        return Inertia::render('dashboard');
    })->name('dashboard');
});

Route::get('/clicks', [ClickController::class, 'index'])->name('clicks.index');
Route::post('/clicks', [ClickController::class, 'click'])->name('clicks.click');
Route::post('/clicks/reset', [ClickController::class, 'reset'])->name('clicks.reset');

require __DIR__.'/settings.php';
require __DIR__.'/auth.php';
