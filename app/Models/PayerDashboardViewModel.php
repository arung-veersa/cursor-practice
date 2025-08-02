<?php

namespace App\Models;

class PayerDashboardViewModel
{
    private array $pieChartData;
    private int $totalConflicts;
    private array $conflictTypes;

    public function __construct(array $conflictData = [])
    {
        $this->pieChartData = $this->formatPieChartData($conflictData);
        $this->totalConflicts = $this->calculateTotalConflicts($conflictData);
        $this->conflictTypes = $this->extractConflictTypes($conflictData);
    }

    private function formatPieChartData(array $conflictData): array
    {
        $pieData = [];
        
        foreach ($conflictData as $item) {
            $pieData[] = [
                'label' => $item['CONTYPE'],
                'value' => (int) $item['CONFLICT_COUNT'],
                'color' => $this->getColorForConflictType($item['CONTYPE'])
            ];
        }
        
        return $pieData;
    }

    private function calculateTotalConflicts(array $conflictData): int
    {
        $total = 0;
        foreach ($conflictData as $item) {
            $total += (int) $item['CONFLICT_COUNT'];
        }
        return $total;
    }

    private function extractConflictTypes(array $conflictData): array
    {
        $types = [];
        foreach ($conflictData as $item) {
            $types[] = $item['CONTYPE'];
        }
        return array_unique($types);
    }

    private function getColorForConflictType(string $conflictType): string
    {
        // Define colors for different conflict types
        $colorMap = [
            'Type1' => '#FF6384',
            'Type2' => '#36A2EB',
            'Type3' => '#FFCE56',
            'Type4' => '#4BC0C0',
            'Type5' => '#9966FF',
            'Type6' => '#FF9F40',
            'Type7' => '#FF6384',
            'Type8' => '#C9CBCF'
        ];
        
        // Hash the conflict type to get a consistent color
        $colorKeys = array_keys($colorMap);
        $index = abs(crc32($conflictType)) % count($colorKeys);
        
        return $colorMap[$colorKeys[$index]];
    }

    public function getPieChartData(): array
    {
        return $this->pieChartData;
    }

    public function getTotalConflicts(): int
    {
        return $this->totalConflicts;
    }

    public function getConflictTypes(): array
    {
        return $this->conflictTypes;
    }

    public function toArray(): array
    {
        return [
            'pieChartData' => $this->pieChartData,
            'totalConflicts' => $this->totalConflicts,
            'conflictTypes' => $this->conflictTypes
        ];
    }

    public function toJson(): string
    {
        return json_encode($this->toArray());
    }
} 