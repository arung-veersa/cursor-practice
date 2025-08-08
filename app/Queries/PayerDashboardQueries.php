<?php

namespace App\Queries;

class PayerDashboardQueries
{
    /**
     * Get all data from TEST_PY_DB_CON_PRACTICE table
     */
    public static function getAllPayerConflictData(): string
    {
        return "SELECT 
                    PAYERID,
                    CRDATEUNIQUE,
                    CONTYPE,
                    CONTYPES,
                    COSTTYPE,
                    VISITTYPE,
                    STATUSFLAG,
                    CO_TO,
                    CO_SP,
                    CO_OP,
                    CO_FP
                FROM TEST_PY_DB_CON_PRACTICE
                ORDER BY CRDATEUNIQUE DESC";
    }

    /**
     * Get conflict count grouped by conflict type for pie chart
     */
    public static function getConflictCountByType(string $chartType = 'CO_TO'): string
    {
        // Validate chart type to prevent SQL injection
        $validChartTypes = ['CO_TO', 'CO_SP', 'CO_OP', 'CO_FP'];
        if (!in_array($chartType, $validChartTypes)) {
            $chartType = 'CO_TO';
        }
        
        return "SELECT 
                    CONTYPE,
                    SUM({$chartType}) as CONFLICT_COUNT
                FROM TEST_PY_DB_CON_PRACTICE
                WHERE {$chartType} IS NOT NULL
                GROUP BY CONTYPE
                ORDER BY CONFLICT_COUNT DESC";
    }

    /**
     * Get conflict data with filters
     */
    public static function getConflictDataWithFilters(array $filters = []): string
    {
        $baseQuery = "SELECT 
                        PAYERID,
                        CRDATEUNIQUE,
                        CONTYPE,
                        CONTYPES,
                        COSTTYPE,
                        VISITTYPE,
                        STATUSFLAG,
                        CO_TO,
                        CO_SP,
                        CO_OP,
                        CO_FP
                    FROM TEST_PY_DB_CON_PRACTICE";
        
        $whereConditions = [];
        
        if (!empty($filters['dateFrom'])) {
            $whereConditions[] = "CRDATEUNIQUE >= '{$filters['dateFrom']}'";
        }
        
        if (!empty($filters['dateTo'])) {
            $whereConditions[] = "CRDATEUNIQUE <= '{$filters['dateTo']}'";
        }
        
        if (!empty($filters['statusFlag'])) {
            if (is_array($filters['statusFlag'])) {
                $statusConditions = array_map(function($status) {
                    return "'{$status}'";
                }, $filters['statusFlag']);
                $whereConditions[] = "STATUSFLAG IN (" . implode(", ", $statusConditions) . ")";
            } else {
                $whereConditions[] = "STATUSFLAG = '{$filters['statusFlag']}'";
            }
        }
        
        if (!empty($filters['costType'])) {
            $whereConditions[] = "COSTTYPE = '{$filters['costType']}'";
        }
        
        if (!empty($filters['visitType'])) {
            $whereConditions[] = "VISITTYPE = '{$filters['visitType']}'";
        }
        
        if (!empty($whereConditions)) {
            $baseQuery .= " WHERE " . implode(" AND ", $whereConditions);
        }
        
        $baseQuery .= " ORDER BY CRDATEUNIQUE DESC";
        
        return $baseQuery;
    }

    /**
     * Get conflict count by type with filters
     */
    public static function getConflictCountByTypeWithFilters(array $filters = [], string $chartType = 'CO_TO'): string
    {
        // Validate chart type to prevent SQL injection
        $validChartTypes = ['CO_TO', 'CO_SP', 'CO_OP', 'CO_FP'];
        if (!in_array($chartType, $validChartTypes)) {
            $chartType = 'CO_TO';
        }
        
        $baseQuery = "SELECT 
                        CONTYPE,
                        SUM({$chartType}) as CONFLICT_COUNT
                    FROM TEST_PY_DB_CON_PRACTICE
                    WHERE {$chartType} IS NOT NULL";
        
        $whereConditions = [];
        
        if (!empty($filters['dateFrom'])) {
            $whereConditions[] = "CRDATEUNIQUE >= '{$filters['dateFrom']}'";
        }
        
        if (!empty($filters['dateTo'])) {
            $whereConditions[] = "CRDATEUNIQUE <= '{$filters['dateTo']}'";
        }
        
        if (!empty($filters['statusFlag'])) {
            if (is_array($filters['statusFlag'])) {
                $statusConditions = array_map(function($status) {
                    return "'{$status}'";
                }, $filters['statusFlag']);
                $whereConditions[] = "STATUSFLAG IN (" . implode(", ", $statusConditions) . ")";
            } else {
                $whereConditions[] = "STATUSFLAG = '{$filters['statusFlag']}'";
            }
        }
        
        if (!empty($filters['costType'])) {
            $whereConditions[] = "COSTTYPE = '{$filters['costType']}'";
        }
        
        if (!empty($filters['visitType'])) {
            $whereConditions[] = "VISITTYPE = '{$filters['visitType']}'";
        }
        
        if (!empty($whereConditions)) {
            $baseQuery .= " AND " . implode(" AND ", $whereConditions);
        }
        
        $baseQuery .= " GROUP BY CONTYPE ORDER BY CONFLICT_COUNT DESC";
        
        return $baseQuery;
    }

    /**
     * Get summary statistics
     */
    public static function getSummaryStatistics(): string
    {
        return "SELECT 
                    COUNT(*) as RECORD_COUNT,
                    SUM(CO_TO) as CONFLICT_COUNT,
                    SUM(CO_SP) as SHIFT_IMPACT,
                    SUM(CO_OP) as OVERLAP_IMPACT,
                    SUM(CO_FP) as FINAL_PRICE
                FROM TEST_PY_DB_CON_PRACTICE";
    }

    /**
     * Get summary statistics with filters
     */
    public static function getSummaryStatisticsWithFilters(array $filters = []): string
    {
        $baseQuery = "SELECT 
                        COUNT(*) as RECORD_COUNT,
                        SUM(CO_TO) as CONFLICT_COUNT,
                        SUM(CO_SP) as SHIFT_IMPACT,
                        SUM(CO_OP) as OVERLAP_IMPACT,
                        SUM(CO_FP) as FINAL_PRICE
                    FROM TEST_PY_DB_CON_PRACTICE";
        
        $whereConditions = [];
        
        if (!empty($filters['dateFrom'])) {
            $whereConditions[] = "CRDATEUNIQUE >= '{$filters['dateFrom']}'";
        }
        
        if (!empty($filters['dateTo'])) {
            $whereConditions[] = "CRDATEUNIQUE <= '{$filters['dateTo']}'";
        }
        
        if (!empty($filters['statusFlag'])) {
            if (is_array($filters['statusFlag'])) {
                $statusConditions = array_map(function($status) {
                    return "'{$status}'";
                }, $filters['statusFlag']);
                $whereConditions[] = "STATUSFLAG IN (" . implode(", ", $statusConditions) . ")";
            } else {
                $whereConditions[] = "STATUSFLAG = '{$filters['statusFlag']}'";
            }
        }
        
        if (!empty($filters['costType'])) {
            $whereConditions[] = "COSTTYPE = '{$filters['costType']}'";
        }
        
        if (!empty($filters['visitType'])) {
            $whereConditions[] = "VISITTYPE = '{$filters['visitType']}'";
        }
        
        if (!empty($whereConditions)) {
            $baseQuery .= " WHERE " . implode(" AND ", $whereConditions);
        }
        
        return $baseQuery;
    }

    /**
     * Get distinct values for filter dropdowns
     */
    public static function getDistinctCostTypes(): string
    {
        return "SELECT DISTINCT COSTTYPE FROM TEST_PY_DB_CON_PRACTICE WHERE COSTTYPE IS NOT NULL ORDER BY COSTTYPE";
    }

    public static function getDistinctVisitTypes(): string
    {
        return "SELECT DISTINCT VISITTYPE FROM TEST_PY_DB_CON_PRACTICE WHERE VISITTYPE IS NOT NULL ORDER BY VISITTYPE";
    }

    public static function getDistinctStatusFlags(): string
    {
        return "SELECT DISTINCT STATUSFLAG FROM TEST_PY_DB_CON_PRACTICE WHERE STATUSFLAG IS NOT NULL ORDER BY STATUSFLAG";
    }

    /**
     * Get Venn diagram data (no filters)
     */
    public static function getVennDiagramData(string $metricToShow = 'CO_TO'): string
    {
        // Validate the metric parameter to prevent SQL injection
        $allowedMetrics = ['CO_TO', 'CO_OP', 'CO_FP'];
        $validMetric = in_array($metricToShow, $allowedMetrics) ? $metricToShow : 'CO_TO';
        
        return "SELECT 
                    CONTYPE,
                    CONTYPEDESC,
                    SUM($validMetric) as CONFLICT_COUNT
                FROM PAYER_DASHBOARD_CON_TYP_NEW_CALC
                WHERE $validMetric IS NOT NULL
                GROUP BY CONTYPE, CONTYPEDESC 
                ORDER BY CONFLICT_COUNT DESC";
    }

    /**
     * Get Venn diagram data with filters
     */
    public static function getVennDiagramDataWithFilters(array $filters = [], string $metricToShow = 'CO_TO'): string
    {
        // Validate the metric parameter to prevent SQL injection
        $allowedMetrics = ['CO_TO', 'CO_OP', 'CO_FP'];
        $validMetric = in_array($metricToShow, $allowedMetrics) ? $metricToShow : 'CO_TO';
        
        $baseQuery = "SELECT 
                        CONTYPE,
                        CONTYPEDESC,
                        SUM($validMetric) as CONFLICT_COUNT
                    FROM PAYER_DASHBOARD_CON_TYP_NEW_CALC
                    WHERE $validMetric IS NOT NULL";
        
        $whereConditions = [];
        
        if (!empty($filters['dateFrom'])) {
            $whereConditions[] = "CRDATEUNIQUE >= '{$filters['dateFrom']}'";
        }
        
        if (!empty($filters['dateTo'])) {
            $whereConditions[] = "CRDATEUNIQUE <= '{$filters['dateTo']}'";
        }
        
        if (!empty($filters['statusFlag'])) {
            if (is_array($filters['statusFlag'])) {
                $statusConditions = array_map(function($status) {
                    return "'{$status}'";
                }, $filters['statusFlag']);
                $whereConditions[] = "STATUSFLAG IN (" . implode(", ", $statusConditions) . ")";
            } else {
                $whereConditions[] = "STATUSFLAG = '{$filters['statusFlag']}'";
            }
        }
        
        if (!empty($filters['costType'])) {
            $whereConditions[] = "COSTTYPE = '{$filters['costType']}'";
        }
        
        if (!empty($filters['visitType'])) {
            $whereConditions[] = "VISITTYPE = '{$filters['visitType']}'";
        }
        
        if (!empty($filters['payerId'])) {
            if (is_array($filters['payerId'])) {
                $payerConditions = array_map(function($payer) {
                    return "'{$payer}'";
                }, $filters['payerId']);
                $whereConditions[] = "PAYERID IN (" . implode(", ", $payerConditions) . ")";
            } else {
                $whereConditions[] = "PAYERID = '{$filters['payerId']}'";
            }
        }
        
        if (!empty($whereConditions)) {
            $baseQuery .= " AND " . implode(" AND ", $whereConditions);
        }
        
        $baseQuery .= " GROUP BY CONTYPE, CONTYPEDESC ORDER BY CONFLICT_COUNT DESC";
        
        return $baseQuery;
    }

    /**
     * Get record count for Venn data (no filters)
     */
    public static function getVennRecordCount(string $metricToShow = 'CO_TO'): string
    {
        // Validate the metric parameter to prevent SQL injection
        $allowedMetrics = ['CO_TO', 'CO_OP', 'CO_FP'];
        $validMetric = in_array($metricToShow, $allowedMetrics) ? $metricToShow : 'CO_TO';
        
        return "SELECT COUNT(*) as RECORD_COUNT FROM PAYER_DASHBOARD_CON_TYP_NEW_CALC WHERE $validMetric IS NOT NULL";
    }

    /**
     * Get record count for Venn data with filters
     */
    public static function getVennRecordCountWithFilters(array $filters = [], string $metricToShow = 'CO_TO'): string
    {
        // Validate the metric parameter to prevent SQL injection
        $allowedMetrics = ['CO_TO', 'CO_OP', 'CO_FP'];
        $validMetric = in_array($metricToShow, $allowedMetrics) ? $metricToShow : 'CO_TO';
        
        $baseQuery = "SELECT COUNT(*) as RECORD_COUNT FROM PAYER_DASHBOARD_CON_TYP_NEW_CALC WHERE $validMetric IS NOT NULL";

        $whereConditions = [];

        if (!empty($filters['dateFrom'])) {
            $whereConditions[] = "CRDATEUNIQUE >= '{$filters['dateFrom']}'";
        }

        if (!empty($filters['dateTo'])) {
            $whereConditions[] = "CRDATEUNIQUE <= '{$filters['dateTo']}'";
        }

        if (!empty($filters['statusFlag'])) {
            if (is_array($filters['statusFlag'])) {
                $statusConditions = array_map(function($status) {
                    return "'{$status}'";
                }, $filters['statusFlag']);
                $whereConditions[] = "STATUSFLAG IN (" . implode(", ", $statusConditions) . ")";
            } else {
                $whereConditions[] = "STATUSFLAG = '{$filters['statusFlag']}'";
            }
        }

        if (!empty($filters['costType'])) {
            $whereConditions[] = "COSTTYPE = '{$filters['costType']}'";
        }

        if (!empty($filters['visitType'])) {
            $whereConditions[] = "VISITTYPE = '{$filters['visitType']}'";
        }

        if (!empty($filters['payerId'])) {
            if (is_array($filters['payerId'])) {
                $payerConditions = array_map(function($payer) {
                    return "'{$payer}'";
                }, $filters['payerId']);
                $whereConditions[] = "PAYERID IN (" . implode(", ", $payerConditions) . ")";
            } else {
                $whereConditions[] = "PAYERID = '{$filters['payerId']}'";
            }
        }

        if (!empty($whereConditions)) {
            $baseQuery .= " AND " . implode(" AND ", $whereConditions);
        }

        return $baseQuery;
    }

    /**
     * Get filter options for Venn diagram dashboard
     */
    public static function getVennFilterOptions(): string
    {
        return "SELECT DISTINCT 
                    COSTTYPE,
                    VISITTYPE,
                    STATUSFLAG
                FROM PAYER_DASHBOARD_CON_TYP_NEW_CALC 
                WHERE COSTTYPE IS NOT NULL 
                   OR VISITTYPE IS NOT NULL 
                   OR STATUSFLAG IS NOT NULL";
    }

    /**
     * Get payer options for filter dropdown
     */
    public static function getPayerOptions(): string
    {
        return "SELECT
                    p.\"Payer Id\" as PAYER_ID,
                    p.\"Payer Name\" as PAYER_NAME
                FROM
                    ANALYTICS_SANDBOX.BI.DIMPAYER p
                WHERE
                    p.\"Payer Id\" IN (
                        SELECT
                            DISTINCT PAYERID
                        FROM
                            PAYER_DASHBOARD_CON_TYP_NEW_CALC
                    ) AND p.\"Is Active\" = TRUE AND p.\"Is Demo\" = FALSE AND p.\"Payer State\" = 'NY'
                ORDER BY
                    p.\"Payer Name\"";
    }
} 