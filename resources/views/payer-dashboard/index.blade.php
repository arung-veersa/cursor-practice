<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payer Dashboard</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- FontAwesome -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    
    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    
    <style>
        .filter-section {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .chart-container {
            position: relative;
            height: 400px;
            margin-bottom: 20px;
        }
        
        .future-widget-container {
            position: relative;
            height: 400px;
            margin-bottom: 20px;
        }
        
        .stats-card {
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
        }
        
        .stats-value {
            font-size: 1.75rem;
            font-weight: bold;
            color: #0d6efd;
        }
        
        .stats-label {
            font-size: 0.875rem;
            color: #6c757d;
            text-transform: uppercase;
        }
        
        .loading-spinner {
            display: none;
            text-align: center;
            padding: 20px;
        }
        
        .error-message {
            color: #dc3545;
            padding: 10px;
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        
        .success-message {
            color: #155724;
            padding: 10px;
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        
        .filter-buttons {
            display: flex;
            align-items: end;
            gap: 10px;
            margin-bottom: 1rem;
        }
        
        .multiselect-container {
            position: relative;
        }
        
        .multiselect-dropdown {
            width: 100%;
            padding: 0.375rem 0.75rem;
            border: 1px solid #ced4da;
            border-radius: 0.25rem;
            background-color: #fff;
            cursor: pointer;
        }
        
        .multiselect-options {
            position: absolute;
            top: 100%;
            left: 0;
            right: 0;
            background: white;
            border: 1px solid #ced4da;
            border-top: none;
            border-radius: 0 0 0.25rem 0.25rem;
            max-height: 200px;
            overflow-y: auto;
            z-index: 1000;
            display: none;
        }
        
        .multiselect-option {
            padding: 0.375rem 0.75rem;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .multiselect-option:hover {
            background-color: #f8f9fa;
        }
        
        .multiselect-option input[type="checkbox"] {
            margin: 0;
        }
        

    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <h1 class="my-4">Payer Dashboard</h1>
                
                <!-- Error/Success Messages -->
                @if(isset($error))
                    <div class="error-message">{{ $error }}</div>
                @endif
                
                <div id="messageContainer"></div>
                
                <!-- Filter Section -->
                <div class="filter-section">
                    <h4>Filters</h4>
                    <form id="filterForm">
                        <div class="d-flex gap-2 align-items-end">
                            <div class="flex-fill">
                                <label for="dateFrom" class="form-label">Date From</label>
                                <input type="date" class="form-control form-control-sm" id="dateFrom" name="dateFrom">
                            </div>
                            
                            <div class="flex-fill">
                                <label for="dateTo" class="form-label">Date To</label>
                                <input type="date" class="form-control form-control-sm" id="dateTo" name="dateTo">
                            </div>
                            
                            <div class="flex-fill">
                                <label for="statusFlag" class="form-label">Status</label>
                                <div class="multiselect-container">
                                    <div class="multiselect-dropdown" id="statusDropdown" style="font-size: 0.875rem; padding: 0.25rem 0.5rem;">
                                        <span id="statusDisplay">All Statuses</span>
                                        <i class="fas fa-chevron-down float-end"></i>
                                    </div>
                                    <div class="multiselect-options" id="statusOptions">
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusAll" checked>
                                            <label for="statusAll">All Statuses</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusU" value="U">
                                            <label for="statusU">Unresolved</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusP" value="P">
                                            <label for="statusP">In Progress</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusW" value="W">
                                            <label for="statusW">Waiting for Response</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusN" value="N">
                                            <label for="statusN">No Resolution</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusR" value="R">
                                            <label for="statusR">Resolved</label>
                                        </div>
                                        <div class="multiselect-option">
                                            <input type="checkbox" id="statusD" value="D">
                                            <label for="statusD">Deleted</label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="flex-fill">
                                <label for="costType" class="form-label">Cost Type</label>
                                <select class="form-select form-select-sm" id="costType" name="costType">
                                    <option value="">All</option>
                                    <option value="Avoidance">Avoidance</option>
                                    <option value="Recovery">Recovery</option>
                                </select>
                            </div>
                            
                            <div class="flex-fill">
                                <label for="visitType" class="form-label">Visit Type</label>
                                <select class="form-select form-select-sm" id="visitType" name="visitType">
                                    <option value="">All</option>
                                    <option value="Scheduled">Scheduled</option>
                                    <option value="Confirmed">Confirmed</option>
                                    <option value="Billed">Billed</option>
                                    <option value="Paid">Paid</option>
                                </select>
                            </div>
                            
                            <div class="flex-fill">
                                <label for="chartType" class="form-label">Chart Data</label>
                                <select class="form-select form-select-sm" id="chartType" name="chartType">
                                    <option value="CO_TO" selected>Conflict Count</option>
                                    <option value="CO_SP">Shift Impact</option>
                                    <option value="CO_OP">Overlap Impact</option>
                                    <option value="CO_FP">Final Impact</option>
                                </select>
                            </div>
                            
                            <div class="flex-fill">
                                <label class="form-label">&nbsp;</label>
                                <div class="d-flex gap-1">
                                    <button type="submit" class="btn btn-primary btn-sm flex-fill" id="applyBtn" title="Apply Filters">
                                        <i class="fas fa-search"></i>
                                    </button>
                                    <button type="button" class="btn btn-secondary btn-sm flex-fill" id="clearBtn" title="Clear Filters">
                                        <i class="fas fa-times"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
                
                <!-- KPI Cards -->
                <div id="statisticsSection" class="d-flex justify-content-between" style="display: none;">
                    <div class="flex-fill mx-1">
                        <div class="stats-card text-center">
                            <div class="stats-value" id="recordCount">0</div>
                            <div class="stats-label">Record Count</div>
                        </div>
                    </div>
                    <div class="flex-fill mx-1">
                        <div class="stats-card text-center">
                            <div class="stats-value" id="conflictCount">0</div>
                            <div class="stats-label">Conflict Count</div>
                        </div>
                    </div>
                    <div class="flex-fill mx-1">
                        <div class="stats-card text-center">
                            <div class="stats-value" id="shiftImpact">$0</div>
                            <div class="stats-label">Shift Impact</div>
                        </div>
                    </div>
                    <div class="flex-fill mx-1">
                        <div class="stats-card text-center">
                            <div class="stats-value" id="overlapImpact">$0</div>
                            <div class="stats-label">Overlap Impact</div>
                        </div>
                    </div>
                    <div class="flex-fill mx-1">
                        <div class="stats-card text-center">
                            <div class="stats-value" id="finalImpact">$0</div>
                            <div class="stats-label">Final Impact</div>
                        </div>
                    </div>
                </div>
                
                <!-- Loading Spinner -->
                <div id="loadingSpinner" class="loading-spinner">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="mt-2">Loading dashboard data...</p>
                </div>
                
                <!-- Chart Section -->
                <div id="chartSection" class="row" style="display: none;">
                    <div class="col-md-6">
                        <div class="stats-card">
                            <h5 id="pieChartTitle">Conflict by Type</h5>
                            <div class="chart-container">
                                <canvas id="conflictPieChart"></canvas>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="stats-card">
                            <h5>Future Widget</h5>
                            <div class="future-widget-container d-flex align-items-center justify-content-center">
                                <div class="text-center text-muted">
                                    <i class="fas fa-chart-line fa-3x mb-3"></i>
                                    <p>This widget is reserved for future enhancements</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    
    <script>
        // Set up CSRF token for AJAX requests
        document.addEventListener('DOMContentLoaded', function() {
            const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
            
            // Global variables
            let pieChart = null;
            const messageContainer = document.getElementById('messageContainer');
            const loadingSpinner = document.getElementById('loadingSpinner');
            const statisticsSection = document.getElementById('statisticsSection');
            const chartSection = document.getElementById('chartSection');
            
            // Form and button elements
            const filterForm = document.getElementById('filterForm');
            const applyBtn = document.getElementById('applyBtn');
            const clearBtn = document.getElementById('clearBtn');
            
            // KPI elements
            const recordCount = document.getElementById('recordCount');
            const conflictCount = document.getElementById('conflictCount');
            const shiftImpact = document.getElementById('shiftImpact');
            const overlapImpact = document.getElementById('overlapImpact');
            const finalImpact = document.getElementById('finalImpact');
            
            // Multi-select elements
            const statusDropdown = document.getElementById('statusDropdown');
            const statusOptions = document.getElementById('statusOptions');
            const statusDisplay = document.getElementById('statusDisplay');
            const statusAll = document.getElementById('statusAll');
            
            // Multi-select functionality
            statusDropdown.addEventListener('click', function() {
                statusOptions.style.display = statusOptions.style.display === 'block' ? 'none' : 'block';
            });
            
            // Close dropdown when clicking outside
            document.addEventListener('click', function(event) {
                if (!statusDropdown.contains(event.target) && !statusOptions.contains(event.target)) {
                    statusOptions.style.display = 'none';
                }
            });
            
            // Handle "All Statuses" checkbox
            statusAll.addEventListener('change', function() {
                const checkboxes = statusOptions.querySelectorAll('input[type="checkbox"]:not(#statusAll)');
                checkboxes.forEach(checkbox => {
                    checkbox.checked = this.checked;
                });
                updateStatusDisplay();
            });
            
            // Handle individual status checkboxes
            statusOptions.addEventListener('change', function(event) {
                if (event.target.type === 'checkbox' && event.target.id !== 'statusAll') {
                    const checkboxes = statusOptions.querySelectorAll('input[type="checkbox"]:not(#statusAll)');
                    const checkedCount = Array.from(checkboxes).filter(cb => cb.checked).length;
                    
                    if (checkedCount === 0) {
                        statusAll.checked = true;
                        checkboxes.forEach(checkbox => checkbox.checked = true);
                    } else if (checkedCount === checkboxes.length) {
                        statusAll.checked = true;
                    } else {
                        statusAll.checked = false;
                    }
                    
                    updateStatusDisplay();
                }
            });
            
            function updateStatusDisplay() {
                const checkboxes = statusOptions.querySelectorAll('input[type="checkbox"]:not(#statusAll)');
                const checkedBoxes = Array.from(checkboxes).filter(cb => cb.checked);
                
                if (statusAll.checked || checkedBoxes.length === checkboxes.length) {
                    statusDisplay.textContent = 'All Statuses';
                } else if (checkedBoxes.length === 0) {
                    statusDisplay.textContent = 'All Statuses';
                } else {
                    const labels = checkedBoxes.map(cb => cb.nextElementSibling.textContent);
                    statusDisplay.textContent = labels.join(', ');
                }
            }
            

            
            // Function to get selected chart type
            function getSelectedChartType() {
                const chartTypeDropdown = document.getElementById('chartType');
                return chartTypeDropdown ? chartTypeDropdown.value : 'CO_TO';
            }
            
            // Function to update chart title based on selected type
            function updateChartTitle() {
                const chartType = getSelectedChartType();
                const chartTitle = document.getElementById('pieChartTitle');
                
                const titleMap = {
                    'CO_TO': 'Conflict Count by Type',
                    'CO_SP': 'Shift Impact by Type',
                    'CO_OP': 'Overlap Impact by Type',
                    'CO_FP': 'Final Impact by Type'
                };
                
                if (chartTitle) {
                    chartTitle.textContent = titleMap[chartType] || 'Conflict by Type';
                }
            }
            

            
            // Utility functions
            function showMessage(message, type = 'success') {
                const alertClass = type === 'success' ? 'success-message' : 'error-message';
                messageContainer.innerHTML = `<div class="${alertClass}">${message}</div>`;
                setTimeout(() => {
                    messageContainer.innerHTML = '';
                }, 5000);
            }
            
            function showLoading() {
                loadingSpinner.style.display = 'block';
                statisticsSection.style.display = 'none';
                chartSection.style.display = 'none';
            }
            
            function hideLoading() {
                loadingSpinner.style.display = 'none';
            }
            
            function formatNumber(number) {
                return Math.round(number).toLocaleString();
            }
            
            function formatCurrency(number) {
                return '$' + formatNumber(number);
            }
            
            function updateStatistics(summary) {
                recordCount.textContent = formatNumber(summary.RECORD_COUNT || 0);
                conflictCount.textContent = formatNumber(summary.CONFLICT_COUNT || 0);
                shiftImpact.textContent = formatCurrency(summary.SHIFT_IMPACT || 0);
                overlapImpact.textContent = formatCurrency(summary.OVERLAP_IMPACT || 0);
                finalImpact.textContent = formatCurrency(summary.FINAL_PRICE || 0);
                
                statisticsSection.style.display = 'flex';
            }
            
            function createPieChart(data) {
                console.log('Creating pie chart with data:', data);
                const ctx = document.getElementById('conflictPieChart').getContext('2d');
                
                // Destroy existing chart if it exists
                if (pieChart) {
                    pieChart.destroy();
                }
                
                // Handle different data structures
                let chartData;
                if (Array.isArray(data)) {
                    chartData = data;
                } else if (data && data.pieChartData) {
                    chartData = data.pieChartData;
                } else {
                    chartData = [];
                }
                
                if (chartData.length === 0) {
                    showMessage('No data available for the selected filters', 'error');
                    chartSection.style.display = 'none';
                    return;
                }
                
                pieChart = new Chart(ctx, {
                    type: 'pie',
                    data: {
                        labels: chartData.map(item => item.label),
                        datasets: [{
                            data: chartData.map(item => item.value),
                            backgroundColor: chartData.map(item => item.color),
                            borderWidth: 2,
                            borderColor: '#ffffff'
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: {
                                display: true,
                                position: 'right',
                                labels: {
                                    boxWidth: 20,
                                    padding: 15,
                                    font: {
                                        size: 12
                                    }
                                }
                            },
                            tooltip: {
                                callbacks: {
                                    label: function(context) {
                                        const label = context.label || '';
                                        const value = context.parsed;
                                        const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                        const percentage = ((value / total) * 100).toFixed(1);
                                        return `${label}: ${value} (${percentage}%)`;
                                    }
                                }
                            }
                        }
                    }
                });
                
                // Update chart title
                updateChartTitle();
                
                chartSection.style.display = 'flex';
            }
            
            function getSelectedStatuses() {
                const checkboxes = statusOptions.querySelectorAll('input[type="checkbox"]:not(#statusAll)');
                const checkedBoxes = Array.from(checkboxes).filter(cb => cb.checked);
                
                if (statusAll.checked || checkedBoxes.length === checkboxes.length) {
                    return []; // Return empty array for "All Statuses"
                }
                
                return checkedBoxes.map(cb => cb.value);
            }
            
            // Event handlers
            filterForm.addEventListener('submit', function(e) {
                e.preventDefault();
                
                showLoading();
                
                const formData = new FormData(filterForm);
                const filters = Object.fromEntries(formData.entries());
                
                // Add selected statuses to filters
                const selectedStatuses = getSelectedStatuses();
                if (selectedStatuses.length > 0) {
                    filters.statusFlag = selectedStatuses;
                }
                
                // Add chart type
                filters.chartType = getSelectedChartType();
                
                fetch('/payer-dashboard/load-data', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRF-TOKEN': csrfToken
                    },
                    body: JSON.stringify(filters)
                })
                .then(response => response.json())
                .then(data => {
                    console.log('Dashboard data response:', data);
                    hideLoading();
                    
                    if (data.success) {
                        updateStatistics(data.data.summary);
                        // Access the correct data structure
                        if (data.data && data.data.pieChart && data.data.pieChart.pieChartData) {
                            createPieChart(data.data.pieChart.pieChartData);
                            showMessage(data.message);
                        } else {
                            showMessage('No chart data available', 'error');
                        }
                    } else {
                        showMessage(data.message, 'error');
                    }
                })
                .catch(error => {
                    hideLoading();
                    showMessage('An error occurred while loading data', 'error');
                    console.error('Error:', error);
                });
            });
            
            clearBtn.addEventListener('click', function() {
                filterForm.reset();
                
                // Reset multi-select
                statusAll.checked = true;
                const checkboxes = statusOptions.querySelectorAll('input[type="checkbox"]:not(#statusAll)');
                checkboxes.forEach(checkbox => {
                    checkbox.checked = true;
                });
                updateStatusDisplay();
                
                // Reset chart type to default (Conflict Count)
                const chartTypeDropdown = document.getElementById('chartType');
                chartTypeDropdown.value = 'CO_TO';
                
                // Reset chart title
                const chartTitle = document.getElementById('pieChartTitle');
                if (chartTitle) {
                    chartTitle.textContent = 'Conflict by Type';
                }
                
                messageContainer.innerHTML = '';
                statisticsSection.style.display = 'none';
                chartSection.style.display = 'none';
                
                if (pieChart) {
                    pieChart.destroy();
                    pieChart = null;
                }
            });
        });
    </script>
</body>
</html> 