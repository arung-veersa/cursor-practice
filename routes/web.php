<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\SnowflakeController;
use App\Http\Controllers\PayerDashboardController;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/snowflake', [SnowflakeController::class, 'index'])->name('snowflake.index');
Route::post('/load-data', [SnowflakeController::class, 'loadData'])->name('load.data');

// Payer Dashboard Routes
Route::get('/payer-dashboard', [PayerDashboardController::class, 'index'])->name('payer.dashboard.index');
Route::post('/payer-dashboard/load-data', [PayerDashboardController::class, 'loadDashboardData'])->name('payer.dashboard.load.data');
Route::post('/payer-dashboard/pie-chart', [PayerDashboardController::class, 'getPieChartData'])->name('payer.dashboard.pie.chart');
Route::post('/payer-dashboard/conflict-data', [PayerDashboardController::class, 'getConflictData'])->name('payer.dashboard.conflict.data');
Route::post('/payer-dashboard/export', [PayerDashboardController::class, 'exportData'])->name('payer.dashboard.export');
Route::get('/payer-dashboard/filter-options', [PayerDashboardController::class, 'getFilterOptions'])->name('payer.dashboard.filter.options');
Route::post('/payer-dashboard/statistics', [PayerDashboardController::class, 'getStatistics'])->name('payer.dashboard.statistics');

// New Payer Dashboard with Venn Diagram
Route::get('/new-payer-dashboard-venn', [PayerDashboardController::class, 'vennDashboard'])->name('payer.dashboard.venn');
Route::post('/new-payer-dashboard-venn/load-data', [PayerDashboardController::class, 'loadVennData'])->name('payer.dashboard.venn.load.data');
