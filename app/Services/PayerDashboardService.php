<?php

namespace App\Services;

use App\Repositories\PayerDashboardRepository;
use App\Models\PayerDashboardViewModel;
use Illuminate\Support\Facades\Log;

class PayerDashboardService
{
    private PayerDashboardRepository $repository;

    public function __construct(PayerDashboardRepository $repository)
    {
        $this->repository = $repository;
    }

    /**
     * Get pie chart data for conflicts by type
     */
    public function getPieChartData(array $filters = [], string $chartType = 'CO_TO'): PayerDashboardViewModel
    {
        try {
            $conflictData = $this->repository->getConflictCountByTypeWithFilters($filters, $chartType);
            
            return new PayerDashboardViewModel($conflictData);
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getPieChartData: ' . $e->getMessage());
            throw new \Exception('Failed to generate pie chart data: ' . $e->getMessage());
        }
    }

    /**
     * Get all payer conflict data
     */
    public function getAllPayerConflictData(array $filters = []): array
    {
        try {
            if (empty($filters)) {
                return $this->repository->getAllPayerConflictData();
            } else {
                return $this->repository->getConflictDataWithFilters($filters);
            }
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getAllPayerConflictData: ' . $e->getMessage());
            throw new \Exception('Failed to fetch payer conflict data: ' . $e->getMessage());
        }
    }

    /**
     * Get dashboard summary data including pie chart and statistics
     */
    public function getDashboardSummary(array $filters = [], string $chartType = 'CO_TO'): array
    {
        try {
            $pieChartData = $this->getPieChartData($filters, $chartType);
            $summaryStats = empty($filters) ? 
                $this->repository->getSummaryStatistics() : 
                $this->repository->getSummaryStatisticsWithFilters($filters);
            
            return [
                'pieChart' => $pieChartData->toArray(),
                'summary' => $summaryStats,
                'filters' => $this->getFilterOptions()
            ];
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getDashboardSummary: ' . $e->getMessage());
            throw new \Exception('Failed to generate dashboard summary: ' . $e->getMessage());
        }
    }

    /**
     * Get filter options for dropdowns
     */
    public function getFilterOptions(): array
    {
        try {
            return [
                'costTypes' => $this->repository->getDistinctCostTypes(),
                'visitTypes' => $this->repository->getDistinctVisitTypes(),
                'statusFlags' => $this->repository->getDistinctStatusFlags()
            ];
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getFilterOptions: ' . $e->getMessage());
            throw new \Exception('Failed to fetch filter options: ' . $e->getMessage());
        }
    }

    /**
     * Validate filters before applying
     */
    public function validateFilters(array $filters): array
    {
        $validatedFilters = [];
        
        // Validate and sanitize filters in the required order
        if (isset($filters['dateFrom']) && !empty($filters['dateFrom'])) {
            $validatedFilters['dateFrom'] = $this->validateDate($filters['dateFrom']);
        }
        
        if (isset($filters['dateTo']) && !empty($filters['dateTo'])) {
            $validatedFilters['dateTo'] = $this->validateDate($filters['dateTo']);
        }
        
        if (isset($filters['statusFlag']) && !empty($filters['statusFlag'])) {
            // Handle multi-select status flags
            if (is_array($filters['statusFlag'])) {
                $validatedFilters['statusFlag'] = array_map([$this, 'sanitizeString'], $filters['statusFlag']);
            } else {
                $validatedFilters['statusFlag'] = $this->sanitizeString($filters['statusFlag']);
            }
        }
        
        if (isset($filters['costType']) && !empty($filters['costType'])) {
            $validatedFilters['costType'] = $this->sanitizeString($filters['costType']);
        }
        
        if (isset($filters['visitType']) && !empty($filters['visitType'])) {
            $validatedFilters['visitType'] = $this->sanitizeString($filters['visitType']);
        }
        
        return $validatedFilters;
    }

    /**
     * Sanitize string input to prevent SQL injection
     */
    private function sanitizeString(string $input): string
    {
        // Remove any potentially dangerous characters
        $sanitized = preg_replace('/[^a-zA-Z0-9_\-\s]/', '', $input);
        return trim($sanitized);
    }

    /**
     * Validate date format
     */
    private function validateDate(string $date): ?string
    {
        $formats = ['Y-m-d', 'd/m/Y', 'm/d/Y', 'Y/m/d'];
        
        foreach ($formats as $format) {
            $dateTime = \DateTime::createFromFormat($format, $date);
            if ($dateTime && $dateTime->format($format) === $date) {
                return $dateTime->format('Y-m-d');
            }
        }
        
        return null;
    }

    /**
     * Process conflict data for export
     */
    public function processDataForExport(array $filters = []): array
    {
        try {
            $conflictData = $this->getAllPayerConflictData($filters);
            
            $exportData = [];
            foreach ($conflictData as $entity) {
                $exportData[] = $entity->toArray();
            }
            
            return $exportData;
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::processDataForExport: ' . $e->getMessage());
            throw new \Exception('Failed to process data for export: ' . $e->getMessage());
        }
    }

    /**
     * Get conflict statistics for additional insights
     */
    public function getConflictStatistics(array $filters = [], string $chartType = 'CO_TO'): array
    {
        try {
            $conflictData = $this->repository->getConflictCountByTypeWithFilters($filters, $chartType);
            
            $statistics = [
                'total_conflicts' => 0,
                'total_types' => count($conflictData),
                'top_conflict_type' => null,
                'distribution' => []
            ];
            
            foreach ($conflictData as $item) {
                $count = (int) $item['CONFLICT_COUNT'];
                $statistics['total_conflicts'] += $count;
                
                if ($statistics['top_conflict_type'] === null || 
                    $count > $statistics['top_conflict_type']['count']) {
                    $statistics['top_conflict_type'] = [
                        'type' => $item['CONTYPE'],
                        'count' => $count
                    ];
                }
                
                $statistics['distribution'][] = [
                    'type' => $item['CONTYPE'],
                    'count' => $count,
                    'percentage' => 0 // Will be calculated after total is known
                ];
            }
            
            // Calculate percentages
            if ($statistics['total_conflicts'] > 0) {
                foreach ($statistics['distribution'] as &$item) {
                    $item['percentage'] = round(($item['count'] / $statistics['total_conflicts']) * 100, 2);
                }
            }
            
            return $statistics;
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getConflictStatistics: ' . $e->getMessage());
            throw new \Exception('Failed to calculate conflict statistics: ' . $e->getMessage());
        }
    }
} 