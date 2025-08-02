<?php

namespace App\Http\Controllers;

use App\Services\SnowflakeService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class SnowflakeController extends Controller
{
    private $snowflakeService;

    public function __construct(SnowflakeService $snowflakeService)
    {
        $this->snowflakeService = $snowflakeService;
    }

    public function index()
    {
        return view('snowflake.index');
    }

    public function loadData(): JsonResponse
    {
        try {
            // Use REST API method since ODBC is not available
            $data = $this->snowflakeService->getSettingsData();
            
            return response()->json([
                'success' => true,
                'data' => $data,
                'message' => 'Data loaded successfully via REST API'
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to load data: ' . $e->getMessage()
            ], 500);
        }
    }
} 