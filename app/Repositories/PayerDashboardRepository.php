<?php

namespace App\Repositories;

use App\Services\SnowflakeService;
use App\Queries\PayerDashboardQueries;
use App\Models\PayerConflictPractice;
use Illuminate\Support\Facades\Log;

class PayerDashboardRepository
{
    private SnowflakeService $snowflakeService;

    public function __construct(SnowflakeService $snowflakeService)
    {
        $this->snowflakeService = $snowflakeService;
    }

    /**
     * Get all payer conflict practice data
     */
    public function getAllPayerConflictData(): array
    {
        try {
            $query = PayerDashboardQueries::getAllPayerConflictData();
            $results = $this->snowflakeService->query($query);
            
            return $this->mapToEntities($results);
        } catch (\Exception $e) {
            Log::error('Error fetching all payer conflict data: ' . $e->getMessage());
            throw new \Exception('Failed to fetch payer conflict data: ' . $e->getMessage());
        }
    }

    /**
     * Get conflict count grouped by conflict type for pie chart
     */
    public function getConflictCountByType(string $chartType = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getConflictCountByType($chartType);
            $results = $this->snowflakeService->query($query);
            
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching conflict count by type: ' . $e->getMessage());
            throw new \Exception('Failed to fetch conflict count by type: ' . $e->getMessage());
        }
    }

    /**
     * Get conflict data with filters
     */
    public function getConflictDataWithFilters(array $filters = []): array
    {
        try {
            $query = PayerDashboardQueries::getConflictDataWithFilters($filters);
            $results = $this->snowflakeService->query($query);
            
            return $this->mapToEntities($results);
        } catch (\Exception $e) {
            Log::error('Error fetching conflict data with filters: ' . $e->getMessage());
            throw new \Exception('Failed to fetch conflict data with filters: ' . $e->getMessage());
        }
    }

    /**
     * Get conflict count by type with filters
     */
    public function getConflictCountByTypeWithFilters(array $filters = [], string $chartType = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getConflictCountByTypeWithFilters($filters, $chartType);
            $results = $this->snowflakeService->query($query);
            
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching conflict count by type with filters: ' . $e->getMessage());
            throw new \Exception('Failed to fetch conflict count by type with filters: ' . $e->getMessage());
        }
    }

    /**
     * Get summary statistics
     */
    public function getSummaryStatistics(): array
    {
        try {
            $query = PayerDashboardQueries::getSummaryStatistics();
            $results = $this->snowflakeService->query($query);
            
            return $results[0] ?? [];
        } catch (\Exception $e) {
            Log::error('Error fetching summary statistics: ' . $e->getMessage());
            throw new \Exception('Failed to fetch summary statistics: ' . $e->getMessage());
        }
    }

    /**
     * Get summary statistics with filters
     */
    public function getSummaryStatisticsWithFilters(array $filters = []): array
    {
        try {
            $query = PayerDashboardQueries::getSummaryStatisticsWithFilters($filters);
            $results = $this->snowflakeService->query($query);
            
            return $results[0] ?? [];
        } catch (\Exception $e) {
            Log::error('Error fetching summary statistics with filters: ' . $e->getMessage());
            throw new \Exception('Failed to fetch summary statistics with filters: ' . $e->getMessage());
        }
    }



    /**
     * Get distinct cost types for filter dropdown
     */
    public function getDistinctCostTypes(): array
    {
        try {
            $query = PayerDashboardQueries::getDistinctCostTypes();
            $results = $this->snowflakeService->query($query);
            
            return array_column($results, 'COSTTYPE');
        } catch (\Exception $e) {
            Log::error('Error fetching distinct cost types: ' . $e->getMessage());
            throw new \Exception('Failed to fetch distinct cost types: ' . $e->getMessage());
        }
    }

    /**
     * Get distinct visit types for filter dropdown
     */
    public function getDistinctVisitTypes(): array
    {
        try {
            $query = PayerDashboardQueries::getDistinctVisitTypes();
            $results = $this->snowflakeService->query($query);
            
            return array_column($results, 'VISITTYPE');
        } catch (\Exception $e) {
            Log::error('Error fetching distinct visit types: ' . $e->getMessage());
            throw new \Exception('Failed to fetch distinct visit types: ' . $e->getMessage());
        }
    }

    /**
     * Get distinct status flags for filter dropdown
     */
    public function getDistinctStatusFlags(): array
    {
        try {
            $query = PayerDashboardQueries::getDistinctStatusFlags();
            $results = $this->snowflakeService->query($query);
            
            return array_column($results, 'STATUSFLAG');
        } catch (\Exception $e) {
            Log::error('Error fetching distinct status flags: ' . $e->getMessage());
            throw new \Exception('Failed to fetch distinct status flags: ' . $e->getMessage());
        }
    }

    /**
     * Get Venn diagram data (no filters)
     */
    public function getVennDiagramData(string $metricToShow = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getVennDiagramData($metricToShow);
            $results = $this->snowflakeService->query($query);
            
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching Venn diagram data: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn diagram data: ' . $e->getMessage());
        }
    }

    /**
     * Get Venn diagram data with filters
     */
    public function getVennDiagramDataWithFilters(array $filters = [], string $metricToShow = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getVennDiagramDataWithFilters($filters, $metricToShow);
            $results = $this->snowflakeService->query($query);
            
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching Venn diagram data with filters: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn diagram data with filters: ' . $e->getMessage());
        }
    }

    /**
     * Get Venn record count (no filters)
     */
    public function getVennRecordCount(string $metricToShow = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getVennRecordCount($metricToShow);
            $results = $this->snowflakeService->query($query);
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching Venn record count: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn record count: ' . $e->getMessage());
        }
    }

    /**
     * Get Venn record count with filters
     */
    public function getVennRecordCountWithFilters(array $filters = [], string $metricToShow = 'CO_TO'): array
    {
        try {
            $query = PayerDashboardQueries::getVennRecordCountWithFilters($filters, $metricToShow);
            $results = $this->snowflakeService->query($query);
            return $results;
        } catch (\Exception $e) {
            Log::error('Error fetching Venn record count with filters: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn record count with filters: ' . $e->getMessage());
        }
    }

    /**
     * Get Venn diagram filter options
     */
    public function getVennFilterOptions(): array
    {
        try {
            $query = PayerDashboardQueries::getVennFilterOptions();
            $results = $this->snowflakeService->query($query);
            
            $options = [
                'costTypes' => [],
                'visitTypes' => [],
                'statusFlags' => []
            ];
            
            foreach ($results as $row) {
                if (!empty($row['COSTTYPE'])) {
                    $options['costTypes'][] = $row['COSTTYPE'];
                }
                if (!empty($row['VISITTYPE'])) {
                    $options['visitTypes'][] = $row['VISITTYPE'];
                }
                if (!empty($row['STATUSFLAG'])) {
                    $options['statusFlags'][] = $row['STATUSFLAG'];
                }
            }
            
            // Remove duplicates and sort
            $options['costTypes'] = array_unique($options['costTypes']);
            $options['visitTypes'] = array_unique($options['visitTypes']);
            $options['statusFlags'] = array_unique($options['statusFlags']);
            
            sort($options['costTypes']);
            sort($options['visitTypes']);
            sort($options['statusFlags']);
            
            return $options;
        } catch (\Exception $e) {
            Log::error('Error fetching Venn filter options: ' . $e->getMessage());
            throw new \Exception('Failed to fetch Venn filter options: ' . $e->getMessage());
        }
    }

    /**
     * Get payer options for filter dropdown
     */
    public function getPayerOptions(): array
    {
        try {
            $query = PayerDashboardQueries::getPayerOptions();
            $results = $this->snowflakeService->query($query);
            
            $options = [];
            foreach ($results as $row) {
                if (!empty($row['PAYER_ID']) && !empty($row['PAYER_NAME'])) {
                    $options[] = [
                        'id' => $row['PAYER_ID'],
                        'name' => $row['PAYER_NAME']
                    ];
                }
            }
            
            return $options;
        } catch (\Exception $e) {
            Log::error('Error fetching payer options: ' . $e->getMessage());
            throw new \Exception('Failed to fetch payer options: ' . $e->getMessage());
        }
    }

    /**
     * Map raw database results to PayerConflictPractice entities
     */
    private function mapToEntities(array $results): array
    {
        $entities = [];
        
        foreach ($results as $row) {
            $entities[] = new PayerConflictPractice($row);
        }
        
        return $entities;
    }
} 