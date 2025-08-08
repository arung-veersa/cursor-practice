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
        
        if (isset($filters['payerId']) && !empty($filters['payerId'])) {
            // Handle multi-select payer IDs
            if (is_array($filters['payerId'])) {
                $validatedFilters['payerId'] = array_map([$this, 'sanitizeString'], $filters['payerId']);
            } else {
                $validatedFilters['payerId'] = $this->sanitizeString($filters['payerId']);
            }
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
                'total_types' => is_array($conflictData) ? count($conflictData) : 0,
                'top_conflict_type' => null,
                'distribution' => []
            ];
            
            foreach ($conflictData as $item) {
                if (!is_array($item)) {
                    continue;
                }
                $count = isset($item['CONFLICT_COUNT']) ? (int) $item['CONFLICT_COUNT'] : 0;
                $type = $item['CONTYPE'] ?? '';
                $statistics['total_conflicts'] += $count;
                
                if ($statistics['top_conflict_type'] === null || 
                    $count > ($statistics['top_conflict_type']['count'] ?? -1)) {
                    $statistics['top_conflict_type'] = [
                        'type' => $type,
                        'count' => $count
                    ];
                }
                
                $statistics['distribution'][] = [
                    'type' => $type,
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

    /**
     * Get Venn diagram data
     */
    public function getVennDiagramData(array $filters = [], string $metricToShow = 'CO_TO'): array
    {
        try {
            $vennData = empty($filters) ?
                $this->repository->getVennDiagramData($metricToShow) :
                $this->repository->getVennDiagramDataWithFilters($filters, $metricToShow);

            $processed = $this->processVennData($vennData, $metricToShow);

            // Add record_count separately
            $recordCount = empty($filters)
                ? $this->repository->getVennRecordCount($metricToShow)
                : $this->repository->getVennRecordCountWithFilters($filters, $metricToShow);

            // Ensure recordCount is an integer, handling cases where it might be null or an empty array
            $processed['record_count'] = (int) ($recordCount[0]['RECORD_COUNT'] ?? 0);

            return $processed;
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getVennDiagramData: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn diagram data: ' . $e->getMessage());
        }
    }

    /**
     * Process Venn diagram data for visualization
     */
    private function processVennData(array $vennData, string $metricToShow = 'CO_TO'): array
    {
        $processedData = [
            'sets' => [
                ['name' => 'Time Overlap', 'size' => 0],
                ['name' => 'Time Distance', 'size' => 0],
                ['name' => 'In Service', 'size' => 0]
            ],
            'intersections' => [],
            'total_conflicts' => 0,
            'vennData' => [] // This will be the format expected by venn.js
        ];

        $setMapping = [
            'only_to' => ['Time Overlap'], // Time Overlap only
            'only_td' => ['Time Distance'], // Time Distance only
            'only_is' => ['In Service'], // In Service only
            'both_to_td' => ['Time Overlap', 'Time Distance'], // Time Overlap and Time Distance
            'both_to_is' => ['Time Overlap', 'In Service'], // Time Overlap and In Service
            'both_td_is' => ['Time Distance', 'In Service'], // Time Distance and In Service
            'all_to_td_is' => ['Time Overlap', 'Time Distance', 'In Service'] // All three sets
        ];

        // Initialize intersection counters
        $intersections = [
            'Time Overlap&Time Distance' => 0,
            'Time Overlap&In Service' => 0,
            'Time Distance&In Service' => 0,
            'Time Overlap&Time Distance&In Service' => 0
        ];

        foreach ($vennData as $item) {
            if (!is_array($item)) {
                continue;
            }
            $contype = isset($item["CONTYPE"]) ? strtolower((string) $item['CONTYPE']) : '';
            $count = isset($item['CONFLICT_COUNT']) ? (int) $item['CONFLICT_COUNT'] : 0;
            $description = $item['CONTYPEDESC'] ?? '';

            $processedData['total_conflicts'] += $count;

            if (isset($setMapping[$contype])) {
                $sets = $setMapping[$contype];
                
                // Add to venn.js data format
                $processedData['vennData'][] = [
                    'sets' => $sets,
                    'size' => $count,
                    'description' => $description
                ];
                
                // Update individual set sizes and intersections
                if (count($sets) === 1) {
                    // Single set (only values)
                    $setIndex = array_search($sets[0], ['Time Overlap', 'Time Distance', 'In Service']);
                    if ($setIndex !== false) {
                        $processedData['sets'][$setIndex]['size'] += $count;
                    }
                } elseif (count($sets) === 2) {
                    // Two-set intersection
                    $intersectionKey = implode('&', $sets);
                    $intersections[$intersectionKey] += $count;
                    
                    // Also add to individual sets (for total counts)
                    foreach ($sets as $set) {
                        $setIndex = array_search($set, ['Time Overlap', 'Time Distance', 'In Service']);
                        if ($setIndex !== false) {
                            $processedData['sets'][$setIndex]['size'] += $count;
                        }
                    }
                } elseif (count($sets) === 3) {
                    // Three-set intersection
                    $intersections['Time Overlap&Time Distance&In Service'] += $count;
                    
                    // Also add to individual sets (for total counts)
                    foreach ($sets as $set) {
                        $setIndex = array_search($set, ['Time Overlap', 'Time Distance', 'In Service']);
                        if ($setIndex !== false) {
                            $processedData['sets'][$setIndex]['size'] += $count;
                        }
                    }
                }
            }
        }

        // Add intersections to processed data
        $processedData['intersections'] = $intersections;

        return $processedData;
    }

    /**
     * Get Venn diagram filter options
     */
    public function getVennFilterOptions(): array
    {
        try {
            return $this->repository->getVennFilterOptions();
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getVennFilterOptions: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn filter options: ' . $e->getMessage());
        }
    }

    /**
     * Get payer options for filter dropdown
     */
    public function getPayerOptions(): array
    {
        try {
            return $this->repository->getPayerOptions();
        } catch (\Exception $e) {
            Log::error('Error in PayerDashboardService::getPayerOptions: ' . $e->getMessage());
            throw new \Exception('Failed to fetch payer options: ' . $e->getMessage());
        }
    }
} 