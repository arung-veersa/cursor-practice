<?php

namespace App\Http\Controllers;

use App\Services\PayerDashboardService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\View\View;
use Illuminate\Support\Facades\Log;

class PayerDashboardController extends Controller
{
    private PayerDashboardService $payerDashboardService;

    public function __construct(PayerDashboardService $payerDashboardService)
    {
        $this->payerDashboardService = $payerDashboardService;
    }

    /**
     * Display the payer dashboard page
     */
    public function index(): View
    {
        try {
            // Get initial filter options for dropdowns
            $filterOptions = $this->payerDashboardService->getFilterOptions();
            
            return view('payer-dashboard.index', [
                'filterOptions' => $filterOptions
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading payer dashboard: ' . $e->getMessage());
            return view('payer-dashboard.index', [
                'filterOptions' => [],
                'error' => 'Failed to load dashboard: ' . $e->getMessage()
            ]);
        }
    }

    /**
     * Handle Apply button click to load dashboard data
     */
    public function loadDashboardData(Request $request): JsonResponse
    {
        try {
            // Get filters from request
            $filters = $request->only([
                'dateFrom', 
                'dateTo',
                'statusFlag', 
                'costType', 
                'visitType'
            ]);
            
            $chartType = $request->get('chartType', 'CO_TO');
            
            // Validate filters
            $validatedFilters = $this->payerDashboardService->validateFilters($filters);
            
            // Get dashboard summary data
            $dashboardData = $this->payerDashboardService->getDashboardSummary($validatedFilters, $chartType);
            
            // Get additional statistics
            $statistics = $this->payerDashboardService->getConflictStatistics($validatedFilters, $chartType);
            
            return response()->json([
                'success' => true,
                'data' => $dashboardData,
                'statistics' => $statistics,
                'appliedFilters' => $validatedFilters,
                'message' => 'Dashboard data loaded successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading dashboard data: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load dashboard data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get pie chart data specifically
     */
    public function getPieChartData(Request $request): JsonResponse
    {
        try {
            $filters = $request->only([
                'dateFrom', 
                'dateTo',
                'statusFlag', 
                'costType', 
                'visitType'
            ]);
            
            $chartType = $request->get('chartType', 'CO_TO');
            
            $validatedFilters = $this->payerDashboardService->validateFilters($filters);
            $pieChartData = $this->payerDashboardService->getPieChartData($validatedFilters, $chartType);
            
            return response()->json([
                'success' => true,
                'data' => $pieChartData->toArray(),
                'message' => 'Pie chart data loaded successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading pie chart data: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load pie chart data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get detailed conflict data for table view
     */
    public function getConflictData(Request $request): JsonResponse
    {
        try {
            $filters = $request->only([
                'dateFrom', 
                'dateTo',
                'statusFlag', 
                'costType', 
                'visitType'
            ]);
            
            $validatedFilters = $this->payerDashboardService->validateFilters($filters);
            $conflictData = $this->payerDashboardService->getAllPayerConflictData($validatedFilters);
            
            // Convert entities to arrays for JSON response
            $responseData = [];
            foreach ($conflictData as $entity) {
                $responseData[] = $entity->toArray();
            }
            
            return response()->json([
                'success' => true,
                'data' => $responseData,
                'count' => count($responseData),
                'message' => 'Conflict data loaded successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading conflict data: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load conflict data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Export conflict data as CSV
     */
    public function exportData(Request $request): JsonResponse
    {
        try {
            $filters = $request->only([
                'dateFrom', 
                'dateTo',
                'statusFlag', 
                'costType', 
                'visitType'
            ]);
            
            $validatedFilters = $this->payerDashboardService->validateFilters($filters);
            $exportData = $this->payerDashboardService->processDataForExport($validatedFilters);
            
            return response()->json([
                'success' => true,
                'data' => $exportData,
                'message' => 'Export data prepared successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error preparing export data: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to prepare export data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get filter options for dropdowns
     */
    public function getFilterOptions(): JsonResponse
    {
        try {
            $filterOptions = $this->payerDashboardService->getFilterOptions();
            
            return response()->json([
                'success' => true,
                'data' => $filterOptions,
                'message' => 'Filter options loaded successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading filter options: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load filter options: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get conflict statistics
     */
    public function getStatistics(Request $request): JsonResponse
    {
        try {
            $filters = $request->only([
                'dateFrom', 
                'dateTo',
                'statusFlag', 
                'costType', 
                'visitType'
            ]);
            
            $chartType = $request->get('chartType', 'CO_TO');
            
            $validatedFilters = $this->payerDashboardService->validateFilters($filters);
            $statistics = $this->payerDashboardService->getConflictStatistics($validatedFilters, $chartType);
            
            return response()->json([
                'success' => true,
                'data' => $statistics,
                'message' => 'Statistics loaded successfully'
            ]);
        } catch (\Exception $e) {
            Log::error('Error loading statistics: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Failed to load statistics: ' . $e->getMessage()
            ], 500);
        }
    }
} 