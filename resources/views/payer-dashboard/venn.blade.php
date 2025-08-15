<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payer Dashboard - New Calculations</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- FontAwesome -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    
    <!-- Select2 CSS for enhanced multi-select -->
    <link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" />
    <link href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme@1.3.0/dist/select2-bootstrap-5-theme.min.css" rel="stylesheet" />
    
    <!-- D3.js for SVG manipulation -->
    <script src="https://d3js.org/d3.v5.min.js"></script>
    
    <!-- Chart.js for doughnut chart -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    
    <!-- UpSetJS for UpSet charts -->
    <script src="https://cdn.jsdelivr.net/npm/@upsetjs/bundle"></script>
    
    <style>
        .filter-section {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .venn-container {
            position: relative;
            height: 600px;
            margin-bottom: 20px;
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            overflow: hidden;
            z-index: 1;
        }
        
        .doughnut-container {
            position: relative;
            height: 600px;
            margin-bottom: 20px;
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            display: flex;
            flex-direction: column;
        }
        
        .doughnut-container #doughnutChart {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }
        
        .doughnut-container canvas {
            max-height: 500px !important;
        }
        
        .upset-container {
            position: relative;
            height: 600px;
            margin-bottom: 20px;
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            display: flex;
            flex-direction: column;
        }
        
        .upset-container #upsetChart {
            flex: 1;
            position: relative;
            overflow: hidden;
        }
        
        .upset-container .section-title {
            margin-bottom: 15px;
            color: #495057;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 8px;
        }
        
        .venn-container #vennDiagram {
            width: 100%;
            height: 100%;
            overflow: hidden;
            position: relative;
            z-index: 1;
        }
        
        .venn-container #vennDiagram svg {
            width: 100% !important;
            height: 100% !important;
            max-width: 100% !important;
            max-height: 100% !important;
            position: absolute;
            top: 0;
            left: 0;
            z-index: 1;
        }
        
        .venn-data-container {
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            height: auto;
            overflow: visible;
            position: relative;
            z-index: 2;
        }
        
        .venn-data-container h5 {
            margin-bottom: 15px;
            color: #495057;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 8px;
        }
        
        .venn-data-container .table {
            font-size: 0.95rem;
        }
        
        .venn-data-container .table th {
            background-color: #f8f9fa;
            border-top: none;
            font-weight: 600;
            color: #495057;
        }
        
        .venn-data-container .table td {
            vertical-align: middle;
            padding: 12px 14px;
        }
        
        .venn-data-container .table tbody tr:hover {
            background-color: #f8f9fa;
        }
        
        .venn-data-container .badge {
            font-size: 0.75rem;
        }
        
        .venn-data-container .table-primary {
            background-color: rgba(13, 110, 253, 0.1) !important;
        }
        
        .venn-data-container .table-warning {
            background-color: rgba(255, 193, 7, 0.1) !important;
        }
        
        .venn-data-container .table-danger {
            background-color: rgba(220, 53, 69, 0.1) !important;
        }
        
        .venn-data-container .table-dark {
            background-color: #343a40 !important;
            color: white;
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
        
        .venn-tooltip {
            position: absolute;
            background-color: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            pointer-events: none;
            z-index: 1000;
            display: none;
        }
        
        .venn-legend {
            margin-top: 20px;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 8px;
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            margin-bottom: 8px;
        }
        
        .legend-color {
            width: 20px;
            height: 20px;
            border-radius: 50%;
            margin-right: 10px;
        }
        
        .nav-link {
            color: #0d6efd;
            text-decoration: none;
        }
        
        .nav-link:hover {
            text-decoration: underline;
        }

        .section-title {
            margin-bottom: 12px;
            font-weight: 600;
            color: #343a40;
        }
        
        /* Select2 custom styles */
        .select2-container--bootstrap-5 .select2-selection {
            min-height: 38px;
            border: 1px solid #ced4da;
            border-radius: 0.375rem;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple {
            min-height: 38px;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-selection__choice {
            background-color: #0d6efd;
            border: 1px solid #0d6efd;
            color: white;
            border-radius: 0.25rem;
            padding: 2px 8px;
            margin: 2px;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-selection__choice__remove {
            color: white;
            margin-right: 5px;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-selection__choice__remove:hover {
            color: #f8f9fa;
        }
        
        /* Payer select container fixes */
        .payer-select-container {
            position: relative;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple {
            min-height: 31px !important;
            max-height: 31px !important;
            height: 31px !important;
            overflow: hidden;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-selection__rendered {
            height: 25px !important;
            max-height: 25px !important;
            overflow: hidden;
            padding: 4px 8px;
            display: block;
            line-height: 1.4;
            white-space: nowrap;
            text-overflow: ellipsis;
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-selection__choice {
            display: none; /* Hide individual choice pills when using custom display */
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-search--inline {
            display: none; /* Hide search input to maintain fixed height */
        }
        
        .select2-container--bootstrap-5 .select2-selection--multiple .select2-search--inline .select2-search__field {
            display: none;
        }
        
        /* Payer dropdown with checkboxes */
        .select2-container--bootstrap-5 .select2-results__option {
            padding: 6px 12px;
            cursor: pointer;
        }
        
        .select2-container--bootstrap-5 .select2-results__option:hover {
            background-color: #f8f9fa;
        }
        
        .payer-custom-display {
            color: #495057;
            font-size: 13px;
            line-height: 1.4;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        
        /* KPI Section Styles */
        .kpi-section {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            border: 1px solid #dee2e6;
        }
        
        .kpi-card {
            background: linear-gradient(135deg, #ffffff 0%, #f8f9fa 100%);
            border: 1px solid #e9ecef;
            border-radius: 12px;
            padding: 20px;
            height: 120px;
            display: flex;
            align-items: center;
            transition: all 0.3s ease;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            position: relative;
            overflow: hidden;
        }
        
        .kpi-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            border-color: #0d6efd;
        }
        
        .kpi-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #0d6efd, #6610f2, #6f42c1);
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        
        .kpi-card:hover::before {
            opacity: 1;
        }
        
        .kpi-icon {
            font-size: 24px;
            color: #0d6efd;
            margin-right: 15px;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(13, 110, 253, 0.1);
            border-radius: 50%;
            flex-shrink: 0;
        }
        
        .kpi-content {
            flex: 1;
        }
        
        .kpi-value {
            font-size: 22px;
            font-weight: 700;
            color: #212529;
            line-height: 1;
            margin-bottom: 5px;
            transition: all 0.3s ease;
        }
        
        .kpi-label {
            font-size: 12px;
            color: #6c757d;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            line-height: 1.2;
        }
        
        /* Responsive adjustments for KPI cards */
        @media (max-width: 768px) {
            .kpi-card {
                height: 100px;
                padding: 15px;
            }
            
            .kpi-value {
                font-size: 20px;
            }
            
            .kpi-icon {
                font-size: 20px;
                width: 35px;
                height: 35px;
                margin-right: 12px;
            }
        }
        
        /* Individual KPI card color variations */
        .kpi-card:nth-child(1) .kpi-icon { color: #0d6efd; background: rgba(13, 110, 253, 0.1); }
        .kpi-card:nth-child(2) .kpi-icon { color: #198754; background: rgba(25, 135, 84, 0.1); }
        .kpi-card:nth-child(3) .kpi-icon { color: #fd7e14; background: rgba(253, 126, 20, 0.1); }
        .kpi-card:nth-child(4) .kpi-icon { color: #6610f2; background: rgba(102, 16, 242, 0.1); }
        .kpi-card:nth-child(5) .kpi-icon { color: #dc3545; background: rgba(220, 53, 69, 0.1); }
        
        /* Custom date input styles */
        .date-input-wrapper {
            position: relative;
        }
        
        .date-display {
            font-family: monospace;
            letter-spacing: 0.5px;
            background-color: #fff;
            padding-right: 30px;
        }
        
        .date-display:focus {
            border-color: #0d6efd;
            box-shadow: 0 0 0 0.2rem rgba(13, 110, 253, 0.25);
        }
        
        .date-display::placeholder {
            color: #6c757d;
            font-style: italic;
        }
        
        .date-input-wrapper::after {
            content: '\f073';
            font-family: 'Font Awesome 6 Free';
            font-weight: 900;
            position: absolute;
            right: 8px;
            top: 50%;
            transform: translateY(-50%);
            color: #6c757d;
            pointer-events: none;
            font-size: 12px;
            z-index: 10;
        }
        
        .date-picker {
            z-index: 5;
        }
        
        .date-display:hover {
            border-color: #0d6efd;
        }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h4 class="my-2">Payer Dashboard - New Calculations</h4>
                    <div>
                        <a href="{{ route('payer.dashboard.index') }}" class="nav-link">
                            <i class="fas fa-chart-pie"></i> Original Dashboard
                        </a>
                    </div>
                </div>
                
                <!-- Error/Success Messages -->
                @if(isset($error))
                    <div class="error-message">{{ $error }}</div>
                @endif
                
                <div id="messageContainer"></div>
                
                <!-- Filter Section -->
                <div class="filter-section">
                    <form id="filterForm">
                        <div class="row align-items-end g-2">
                            <div class="col-lg col-md-2 col-sm-6">
                                <label for="metricToShow" class="form-label">Metric</label>
                                <select class="form-select form-select-sm" id="metricToShow" name="metricToShow">
                                    <option value="CO_TO" selected>Count</option>
                                    <option value="CO_OP">$ Impact</option>
                                    <option value="CO_FP">Final $</option>
                                </select>
                            </div>
                            
                            <div class="col-lg-2 col-md-3 col-sm-6">
                                <label for="payerId" class="form-label">Payer</label>
                                <div class="payer-select-container">
                                    <select class="form-select form-select-sm" id="payerId" name="payerId[]" multiple>
                                        @if(isset($payerOptions))
                                            @foreach($payerOptions as $payer)
                                                <option value="{{ $payer['id'] }}">{{ $payer['name'] }}</option>
                                            @endforeach
                                        @endif
                                    </select>
                                </div>
                            </div>
                            
                            <div class="col-lg col-md-2 col-sm-6">
                                <label for="dateFrom" class="form-label">Date From</label>
                                <div class="date-input-wrapper">
                                    <input type="date" class="form-control form-control-sm date-picker" id="dateFrom" name="dateFrom" style="position: absolute; opacity: 0; width: 100%; height: 100%; cursor: pointer;">
                                    <input type="text" class="form-control form-control-sm date-display" id="dateFromDisplay" placeholder="mm/dd/yyyy" readonly style="pointer-events: none;">
                                </div>
                            </div>
                            
                            <div class="col-lg col-md-2 col-sm-6">
                                <label for="dateTo" class="form-label">Date To</label>
                                <div class="date-input-wrapper">
                                    <input type="date" class="form-control form-control-sm date-picker" id="dateTo" name="dateTo" style="position: absolute; opacity: 0; width: 100%; height: 100%; cursor: pointer;">
                                    <input type="text" class="form-control form-control-sm date-display" id="dateToDisplay" placeholder="mm/dd/yyyy" readonly style="pointer-events: none;">
                                </div>
                            </div>
                            
                            <div class="col-lg col-md-2 col-sm-6">
                                <label for="statusFlag" class="form-label">Status</label>
                                <select class="form-select form-select-sm" id="statusFlag" name="statusFlag">
                                    <option value="">All</option>
                                    <option value="U">Unresolved</option>
                                    <option value="R">Resolved</option>
                                    <option value="D">Deleted</option>
                                </select>
                            </div>
                            
                            <div class="col-lg col-md-3 col-sm-6">
                                <label for="costType" class="form-label">Cost Type</label>
                                <select class="form-select form-select-sm" id="costType" name="costType">
                                    <option value="">All Cost Types</option>
                                    @if(isset($filterOptions['costTypes']))
                                        @foreach($filterOptions['costTypes'] as $costType)
                                            <option value="{{ $costType }}">{{ $costType }}</option>
                                        @endforeach
                                    @endif
                                </select>
                            </div>
                            
                            <div class="col-lg col-md-3 col-sm-6">
                                <label for="visitType" class="form-label">Visit Type</label>
                                <select class="form-select form-select-sm" id="visitType" name="visitType">
                                    <option value="">All Visit Types</option>
                                    @if(isset($filterOptions['visitTypes']))
                                        @foreach($filterOptions['visitTypes'] as $visitType)
                                            <option value="{{ $visitType }}">{{ $visitType }}</option>
                                        @endforeach
                                    @endif
                                </select>
                            </div>
                            
                            <div class="col-lg col-md-2 col-sm-6">
                                <button type="submit" class="btn btn-primary btn-sm w-100" aria-label="Apply Filters">
                                    <i class="fas fa-search"></i>
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
                
                <!-- KPI Section -->
                <div class="kpi-section" id="kpiSection" style="display: none;">
                    <div class="row">
                        <div class="col-lg col-md-6 col-sm-6 mb-3">
                            <div class="kpi-card">
                                <div class="kpi-icon">
                                    <i class="fas fa-database"></i>
                                </div>
                                <div class="kpi-content">
                                    <div class="kpi-value" id="kpiRecordCount">-</div>
                                    <div class="kpi-label">Record Count</div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg col-md-6 col-sm-6 mb-3">
                            <div class="kpi-card">
                                <div class="kpi-icon">
                                    <i class="fas fa-clock"></i>
                                </div>
                                <div class="kpi-content">
                                    <div class="kpi-value" id="kpiTimeOverlap">-</div>
                                    <div class="kpi-label">Time Overlap</div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg col-md-6 col-sm-6 mb-3">
                            <div class="kpi-card">
                                <div class="kpi-icon">
                                    <i class="fas fa-route"></i>
                                </div>
                                <div class="kpi-content">
                                    <div class="kpi-value" id="kpiTimeDistance">-</div>
                                    <div class="kpi-label">Time Distance</div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg col-md-6 col-sm-6 mb-3">
                            <div class="kpi-card">
                                <div class="kpi-icon">
                                    <i class="fas fa-tools"></i>
                                </div>
                                <div class="kpi-content">
                                    <div class="kpi-value" id="kpiInService">-</div>
                                    <div class="kpi-label">In Service</div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg col-md-6 col-sm-6 mb-3">
                            <div class="kpi-card">
                                <div class="kpi-icon">
                                    <i class="fas fa-exclamation-triangle"></i>
                                </div>
                                <div class="kpi-content">
                                    <div class="kpi-value" id="kpiTotalConflicts">-</div>
                                    <div class="kpi-label">Total</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Loading Spinner -->
                <div id="loadingSpinner" class="loading-spinner">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="mt-2">Loading Payer dashboard...</p>
                </div>
                
                <!-- Charts Container -->
                <div class="row">
                    <div class="col-md-6">
                        <div class="doughnut-container" id="doughnutContainer">
                            <h5 class="section-title">Distribution Overview</h5>
                            <div id="doughnutChart"></div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="venn-container" id="vennContainer">
                            <h5 class="section-title" id="vennTitle">Conflict by Type</h5>
                            <div id="vennDiagram"></div>
                            <div id="vennTooltip" class="venn-tooltip"></div>
                        </div>
                    </div>
                </div>

                <!-- UpSet Chart Container -->
                <div class="row mt-4">
                    <div class="col-12">
                        <div class="upset-container" id="upsetContainer">
                            <h5 class="section-title">Set Intersection Analysis</h5>
                            <div id="upsetChart"></div>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    </div>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    
    <!-- jQuery (required for Select2) -->
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    
    <!-- Select2 JS for enhanced multi-select -->
    <script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
    
    <script>
        const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        const filterForm = document.getElementById('filterForm');
        const loadingSpinner = document.getElementById('loadingSpinner');
        const messageContainer = document.getElementById('messageContainer');
        const vennContainer = document.getElementById('vennContainer');
        const vennTitle = document.getElementById('vennTitle');
        const metricToShow = document.getElementById('metricToShow');
        
        
        let vennChart = null;
        
        // Metric descriptions for titles
        const metricDescriptions = {
            'CO_TO': 'Conflict Count by Type',
            'CO_OP': 'Conflict $ Impact by Type',
            'CO_FP': 'Final $ Impact by Type'
        };
        
        // Function to update the Venn diagram title
        function updateVennTitle() {
            const selectedMetric = metricToShow.value;
            const description = metricDescriptions[selectedMetric] || 'Conflict by Type';
            vennTitle.textContent = description;
        }
        
        // Remove automatic title update when metric changes - only update after search
        // metricToShow.addEventListener('change', updateVennTitle);
        
        // Initialize title with default
        vennTitle.textContent = 'Conflict by Type';
        
        // Initialize Select2 for payer dropdown with checkboxes
        $(document).ready(function() {
            $('#payerId').select2({
                theme: 'bootstrap-5',
                placeholder: 'All Payers',
                allowClear: true,
                width: '100%',
                closeOnSelect: false,
                templateResult: formatPayerOption,
                templateSelection: formatPayerSelection,
                dropdownParent: $('.payer-select-container')
            });
            
            // Update display when selection changes
            $('#payerId').on('select2:select select2:unselect', function() {
                updatePayerDisplay();
            });
            
            // Initialize display
            setTimeout(() => {
                updatePayerDisplay();
            }, 100);
        });
        
        // Format payer options with checkboxes
        function formatPayerOption(option) {
            if (!option.id) {
                return option.text;
            }
            
            const isSelected = $('#payerId').val() && $('#payerId').val().includes(option.id);
            const checkbox = isSelected ? '☑' : '☐';
            
            return $(`<span>${checkbox} ${option.text}</span>`);
        }
        
        // Format payer selection display
        function formatPayerSelection(option) {
            const selectedValues = $('#payerId').val() || [];
            
            if (selectedValues.length === 0) {
                return 'All Payers';
            } else if (selectedValues.length === 1) {
                return option.text || $('#payerId option[value="' + selectedValues[0] + '"]').text();
            } else {
                return 'Multiple Payers';
            }
        }
        
        // Update payer display
        function updatePayerDisplay() {
            const selectedValues = $('#payerId').val() || [];
            const container = $('#payerId').next('.select2-container').find('.select2-selection__rendered');
            
            let displayText = '';
            if (selectedValues.length === 0) {
                displayText = 'All Payers';
            } else if (selectedValues.length === 1) {
                displayText = $('#payerId option[value="' + selectedValues[0] + '"]').text();
            } else {
                displayText = 'Multiple Payers (' + selectedValues.length + ')';
            }
            
            // Clear existing content and set new text
            container.empty().text(displayText);
            container.attr('title', displayText); // Add tooltip for truncated text
            
            // Update checkboxes in dropdown when it's open
            setTimeout(() => {
                $('.select2-results__option').each(function() {
                    const optionValue = $(this).data('data') ? $(this).data('data').id : null;
                    if (optionValue) {
                        const isSelected = selectedValues.includes(optionValue);
                        const checkbox = isSelected ? '☑' : '☐';
                        const text = $(this).text().replace(/^[☑☐]\s/, '');
                        $(this).html(`${checkbox} ${text}`);
                    }
                });
            }, 50);
        }
        
        function showLoading() {
            loadingSpinner.style.display = 'block';
            vennContainer.style.display = 'none';
            
            // Hide KPI section during loading
            const kpiSection = document.getElementById('kpiSection');
            if (kpiSection) {
                kpiSection.style.display = 'none';
            }
            
            // Hide doughnut chart during loading
            const doughnutContainer = document.getElementById('doughnutContainer');
            if (doughnutContainer) {
                doughnutContainer.style.display = 'none';
            }
            
            // Hide UpSet chart during loading
            const upsetContainer = document.getElementById('upsetContainer');
            if (upsetContainer) {
                upsetContainer.style.display = 'none';
            }
        }
        
        function hideLoading() {
            loadingSpinner.style.display = 'none';
            vennContainer.style.display = 'block';
            
            // Show doughnut chart container
            const doughnutContainer = document.getElementById('doughnutContainer');
            if (doughnutContainer) {
                doughnutContainer.style.display = 'block';
            }
            
            // Show UpSet chart container
            const upsetContainer = document.getElementById('upsetContainer');
            if (upsetContainer) {
                upsetContainer.style.display = 'block';
            }
        }
        
        function showMessage(message, type = 'success') {
            const alertClass = type === 'error' ? 'alert-danger' : 'alert-success';
            messageContainer.innerHTML = `
                <div class="alert ${alertClass} alert-dismissible fade show" role="alert">
                    ${message}
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
            `;
            
            // Auto-hide success messages after 3 seconds
            if (type === 'success') {
                setTimeout(() => {
                    const alert = messageContainer.querySelector('.alert');
                    if (alert) {
                        alert.remove();
                    }
                }, 3000);
            }
        }
        
                function createVennDiagram(data) {
            const vennDiv = document.getElementById('vennDiagram');
            vennDiv.innerHTML = '';
            
            // Use the vennData from the backend
            const vennData = data.vennData || [];
            
            if (vennData.length === 0) {
                vennDiv.innerHTML = '<div class="text-center text-muted mt-5"><h4>No data available</h4></div>';
                return;
            }
            
            try {
                // Check if D3 is available
                if (typeof d3 === 'undefined') {
                    throw new Error('D3.js library not loaded');
                }
                
                // Get container dimensions
                const containerWidth = Math.max(vennDiv.clientWidth || 400, 300);
                const containerHeight = Math.max(vennDiv.clientHeight || 400, 300);
                
                // Create SVG container with responsive dimensions
                const svg = d3.select(vennDiv)
                    .append('svg')
                    .attr('width', '100%')
                    .attr('height', '100%')
                    .attr('viewBox', `0 0 ${containerWidth} ${containerHeight}`)
                    .attr('preserveAspectRatio', 'xMidYMid meet')
                    .style('background', 'white')
                    .style('max-width', '100%')
                    .style('max-height', '100%')
                    .style('overflow', 'hidden');
                
                // Define colors
                const colors = ['#FFB6C1', '#98FB98', '#87CEEB'];
                
                // Process data to get set sizes and intersections
                const setSizes = {
                    'Time Overlap': 0,
                    'Time Distance': 0,
                    'In Service': 0
                };
                
                const intersections = {
                    'Time Overlap&Time Distance': 0,
                    'Time Overlap&In Service': 0,
                    'Time Distance&In Service': 0,
                    'Time Overlap&Time Distance&In Service': 0
                };
                
                // Process the vennData to extract only values and intersections
                vennData.forEach(item => {
                    const sets = Array.isArray(item.sets) ? item.sets : [item.sets];
                    const size = item.size || 0;
                    
                    if (sets.length === 1) {
                        // Only value
                        if (setSizes.hasOwnProperty(sets[0])) {
                            setSizes[sets[0]] = size;
                        }
                    } else if (sets.length === 2) {
                        // Two-set intersection
                        const intersectionKey = sets.join('&');
                        if (intersections.hasOwnProperty(intersectionKey)) {
                            intersections[intersectionKey] = size;
                        }
                    } else if (sets.length === 3) {
                        // Three-set intersection
                        intersections['Time Overlap&Time Distance&In Service'] = size;
                    }
                });
                
                // Calculate circle positions and sizes based on container dimensions
                const centerX = containerWidth / 2;
                const centerY = containerHeight / 2;
                const radius = Math.min(containerWidth, containerHeight) * 0.25; // Increased from 0.15 to 0.25 (25% of smaller dimension)
                
                // Create three circles
                const circles = [
                    { cx: centerX - radius * 0.6, cy: centerY - radius * 0.25, r: radius, color: colors[0], label: 'Time Overlap' },
                    { cx: centerX + radius * 0.6, cy: centerY - radius * 0.25, r: radius, color: colors[1], label: 'Time Distance' },
                    { cx: centerX, cy: centerY + radius * 0.4, r: radius, color: colors[2], label: 'In Service' }
                ];
                
                // Draw circles
                circles.forEach((circle, index) => {
                    const circleGroup = svg.append('g');
                    
                    // Add circle
                    circleGroup.append('circle')
                        .attr('cx', circle.cx)
                        .attr('cy', circle.cy)
                        .attr('r', circle.r)
                        .attr('fill', circle.color)
                        .attr('fill-opacity', 0.6)
                        .attr('stroke', circle.color)
                        .attr('stroke-width', 2)
                        .attr('stroke-opacity', 0.8);
                    
                    // Add label outside the circle
                    let labelX = circle.cx;
                    let labelY = circle.cy;
                    
                    if (index === 0) { // Time Overlap - above circle
                        labelX = circle.cx;
                        labelY = circle.cy - radius - (radius * 0.15);
                    } else if (index === 1) { // Time Distance - above circle
                        labelX = circle.cx;
                        labelY = circle.cy - radius - (radius * 0.15);
                    } else if (index === 2) { // In Service - below circle
                        labelX = circle.cx;
                        labelY = circle.cy + radius + (radius * 0.25);
                    }
                    
                    circleGroup.append('text')
                        .attr('x', labelX)
                        .attr('y', labelY)
                        .attr('text-anchor', 'middle')
                        .attr('font-size', Math.max(14, radius * 0.12) + 'px')
                        .attr('font-weight', 'bold')
                        .attr('fill', 'black')
                        .style('background', 'none') // Remove any background
                        .text(circle.label);
                });
                
                // Add "only" values for each set - positioned near circle edges to avoid intersection areas
                const onlyValues = [
                    { x: circles[0].cx - radius + (radius * 0.3), y: circles[0].cy - (radius * 0.25), value: setSizes['Time Overlap'], label: 'Only TO' }, // Adjusted position to be more within circle
                    { x: circles[1].cx + radius - (radius * 0.25), y: circles[1].cy - (radius * 0.15), value: setSizes['Time Distance'], label: 'Only TD' },
                    { x: circles[2].cx, y: circles[2].cy + radius - (radius * 0.25), value: setSizes['In Service'], label: 'Only IS' }
                ];
                
                onlyValues.forEach(item => {
                    if (item.value > 0) {
                        svg.append('text')
                            .attr('x', item.x)
                            .attr('y', item.y + 5)
                            .attr('text-anchor', 'middle')
                            .attr('font-size', Math.max(12, radius * 0.1) + 'px')
                            .attr('font-weight', 'bold')
                            .attr('fill', 'black')
                            .style('background', 'none') // Remove any background
                            .text(item.value.toLocaleString());
                    }
                });
                
                // Add intersection values in the correct positions
                const intersectionValues = [
                    // All three intersection (center of all circles overlap)
                    { 
                        x: centerX, 
                        y: centerY - (radius * 0.25), 
                        value: intersections['Time Overlap&Time Distance&In Service'], 
                        label: 'All Three',
                        show: intersections['Time Overlap&Time Distance&In Service'] > 0
                    },
                    // Time Overlap & Time Distance intersection (between the two top circles, but not in the center)
                    { 
                        x: centerX, 
                        y: centerY - (radius * 0.75), // Moved slightly up from -0.65 to -0.75
                        value: intersections['Time Overlap&Time Distance'], 
                        label: 'TO & TD',
                        show: intersections['Time Overlap&Time Distance'] > 0
                    },
                    // Time Overlap & In Service intersection (between left and bottom circles)
                    { 
                        x: centerX - (radius * 0.4), 
                        y: centerY + (radius * 0.1), 
                        value: intersections['Time Overlap&In Service'], 
                        label: 'TO & IS',
                        show: intersections['Time Overlap&In Service'] > 0
                    },
                    // Time Distance & In Service intersection (between right and bottom circles)
                    { 
                        x: centerX + (radius * 0.4), 
                        y: centerY + (radius * 0.1), 
                        value: intersections['Time Distance&In Service'], 
                        label: 'TD & IS',
                        show: intersections['Time Distance&In Service'] > 0
                    }
                ];
                
                intersectionValues.forEach(intersection => {
                    if (intersection.show) {
                        svg.append('text')
                            .attr('x', intersection.x)
                            .attr('y', intersection.y + 4)
                            .attr('text-anchor', 'middle')
                            .attr('font-size', Math.max(10, radius * 0.08) + 'px')
                            .attr('font-weight', 'bold')
                            .attr('fill', 'black')
                            .style('background', 'none') // Remove any background
                            .text(intersection.value.toLocaleString());
                    }
                });
                
                // Add hover effects
                svg.selectAll('circle')
                    .on('mouseover', function(d, i) {
                        d3.select(this)
                            .attr('fill-opacity', 0.8)
                            .attr('stroke-width', 3);
                    })
                    .on('mouseout', function(d, i) {
                        d3.select(this)
                            .attr('fill-opacity', 0.6)
                            .attr('stroke-width', 2);
                    });
                
            } catch (error) {
                console.error('Error creating Venn diagram:', error);
                
                // Create a fallback visualization
                createFallbackVisualization(vennDiv, vennData);
            }
        }
        
        let doughnutChart = null;
        
        function createDoughnutChart(data) {
            console.log('createDoughnutChart called with data:', data);
            
            // Extract data with proper fallbacks
            const timeOverlap = (data.sets && data.sets[0] && data.sets[0].size) ? data.sets[0].size : 0;
            const timeDistance = (data.sets && data.sets[1] && data.sets[1].size) ? data.sets[1].size : 0;
            const inService = (data.sets && data.sets[2] && data.sets[2].size) ? data.sets[2].size : 0;

            console.log('Doughnut chart values:', { timeOverlap, timeDistance, inService });

            // Get or create canvas
            const chartContainer = document.getElementById('doughnutChart');
            if (!chartContainer) {
                console.error('Doughnut chart container not found');
                return;
            }

            // Clear existing content
            chartContainer.innerHTML = '';

            // Check if all values are zero
            if (timeOverlap === 0 && timeDistance === 0 && inService === 0) {
                chartContainer.innerHTML = '<div class="text-center text-muted mt-5"><h4>No data available</h4></div>';
                return;
            }

            // Create canvas
            const canvas = document.createElement('canvas');
            canvas.id = 'doughnutChartCanvas';
            chartContainer.appendChild(canvas);

            // Destroy existing chart if it exists
            if (doughnutChart) {
                doughnutChart.destroy();
            }

            // Create new chart
            const ctx = canvas.getContext('2d');
            doughnutChart = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: ['Time Overlap', 'Time Distance', 'In Service'],
                    datasets: [{
                        data: [timeOverlap, timeDistance, inService],
                        backgroundColor: [
                            '#FFB6C1', // Light pink for Time Overlap
                            '#98FB98', // Light green for Time Distance  
                            '#87CEEB'  // Light blue for In Service
                        ],
                        borderColor: [
                            '#FF69B4', // Darker pink
                            '#32CD32', // Darker green
                            '#4682B4'  // Darker blue
                        ],
                        borderWidth: 2,
                        hoverBackgroundColor: [
                            '#FF91A4',
                            '#7FDD7F',
                            '#6BB6D6'
                        ]
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom',
                            labels: {
                                padding: 20,
                                usePointStyle: true,
                                font: {
                                    size: 12
                                }
                            }
                        },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    const label = context.label || '';
                                    const value = context.parsed || 0;
                                    const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                    const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                                    return `${label}: ${value.toLocaleString()} (${percentage}%)`;
                                }
                            }
                        }
                    },
                    cutout: '60%',
                    animation: {
                        animateScale: true,
                        animateRotate: true
                    }
                }
            });
        }
        
        let upsetChart = null;
        
        function createUpSetChart(data) {
            console.log('createUpSetChart called with data:', data);
            
            // Get container
            const chartContainer = document.getElementById('upsetChart');
            if (!chartContainer) {
                console.error('UpSet chart container not found');
                return;
            }

            // Clear existing content
            chartContainer.innerHTML = '';

            try {
                // Process venn data to create UpSet format
                const vennData = data.vennData || [];
                console.log('Venn data for UpSet:', vennData);
                
                // Check if we have any data
                if (vennData.length === 0) {
                    console.log('No venn data available');
                    chartContainer.innerHTML = '<div class="text-center text-muted mt-5"><h4>No data available</h4></div>';
                    return;
                }
                
                // Create UpSet data structure from Venn data
                const upsetData = [];
                let hasValidData = false;
                
                vennData.forEach(item => {
                    const sets = Array.isArray(item.sets) ? item.sets : [item.sets];
                    const size = item.size || 0;
                    
                    console.log('Processing venn item:', { sets, size, item });
                    
                    if (size > 0) {
                        hasValidData = true;
                        upsetData.push({
                            name: sets.length === 1 ? sets[0] : sets.join(' ∩ '),
                            sets: sets,
                            cardinality: size,
                            setCount: sets.length
                        });
                    }
                });

                console.log('UpSet data processed:', upsetData);
                console.log('Has valid data:', hasValidData);

                if (!hasValidData) {
                    chartContainer.innerHTML = '<div class="text-center text-muted mt-5"><h4>No data available</h4></div>';
                    return;
                }

                // Create custom UpSet-style visualization using D3
                createCustomUpSetChart(chartContainer, upsetData);

            } catch (error) {
                console.error('Error creating UpSet chart:', error);
                createUpSetFallback(chartContainer, upsetData || []);
            }
        }
        
        function createCustomUpSetChart(container, data) {
            // Sort data by set count (intersections first) and then by cardinality
            const sortedData = data.sort((a, b) => {
                if (a.setCount !== b.setCount) {
                    return b.setCount - a.setCount; // More sets first (intersections)
                }
                return b.cardinality - a.cardinality; // Higher cardinality first
            });
            
            console.log('Sorted UpSet data:', sortedData);
            
            // Ensure minimum dimensions
            const containerWidth = Math.max(container.clientWidth || 800, 700);
            const containerHeight = Math.max(container.clientHeight || 500, 400);
            const margin = { top: 40, right: 40, bottom: 140, left: 120 }; // Increased bottom margin for matrix
            const chartWidth = Math.max(containerWidth - margin.left - margin.right, 200);
            const chartHeight = Math.max(containerHeight - margin.top - margin.bottom, 150);
            
            // Matrix dimensions
            const matrixHeight = 80;
            const matrixTop = chartHeight + 40;
            
            console.log('Container dimensions:', { containerWidth, containerHeight, chartWidth, chartHeight });
            
            // Create SVG
            const svg = d3.select(container)
                .append('svg')
                .attr('width', containerWidth)
                .attr('height', containerHeight);
                
            const g = svg.append('g')
                .attr('transform', `translate(${margin.left}, ${margin.top})`);
            
            // Scales
            const xScale = d3.scaleBand()
                .domain(sortedData.map(d => d.name))
                .range([0, chartWidth])
                .padding(0.2);
                
            const yScale = d3.scaleLinear()
                .domain([0, d3.max(sortedData, d => d.cardinality)])
                .range([chartHeight, 0]);
            
            // Colors for different set counts
            const colorScale = d3.scaleOrdinal()
                .domain([1, 2, 3])
                .range(['#87CEEB', '#98FB98', '#FFB6C1']); // Single, double, triple intersections
            
            // Create bars
            g.selectAll('.bar')
                .data(sortedData)
                .enter()
                .append('rect')
                .attr('class', 'bar')
                .attr('x', d => xScale(d.name))
                .attr('y', d => yScale(d.cardinality))
                .attr('width', xScale.bandwidth())
                .attr('height', d => Math.max(0, chartHeight - yScale(d.cardinality))) // Ensure non-negative height
                .attr('fill', d => colorScale(d.setCount))
                .attr('opacity', 0.8)
                .on('mouseover', function(d) {
                    d3.select(this).attr('opacity', 1);
                    
                    // Show tooltip
                    const tooltip = d3.select('body').append('div')
                        .attr('class', 'upset-tooltip')
                        .style('position', 'absolute')
                        .style('background', 'rgba(0,0,0,0.8)')
                        .style('color', 'white')
                        .style('padding', '8px')
                        .style('border-radius', '4px')
                        .style('font-size', '12px')
                        .style('pointer-events', 'none')
                        .style('z-index', '1000')
                        .html(`<strong>${d.name}</strong><br/>Count: ${d.cardinality.toLocaleString()}<br/>Sets: ${d.sets.join(', ')}`);
                    
                    tooltip.style('left', (d3.event.pageX + 10) + 'px')
                        .style('top', (d3.event.pageY - 10) + 'px');
                })
                .on('mouseout', function(d) {
                    d3.select(this).attr('opacity', 0.8);
                    d3.selectAll('.upset-tooltip').remove();
                });
            
            // Add x-axis labels above bars (instead of traditional x-axis)
            g.selectAll('.x-label')
                .data(sortedData)
                .enter()
                .append('text')
                .attr('class', 'x-label')
                .attr('x', d => xScale(d.name) + xScale.bandwidth() / 2)
                .attr('y', d => yScale(d.cardinality) - 25) // Position above the numeric values
                .attr('text-anchor', 'middle')
                .attr('font-size', '10px')
                .attr('font-weight', 'normal')
                .attr('fill', '#666')
                .text(d => d.name);
            
            // Add numeric value labels above x-axis labels
            g.selectAll('.bar-label')
                .data(sortedData)
                .enter()
                .append('text')
                .attr('class', 'bar-label')
                .attr('x', d => xScale(d.name) + xScale.bandwidth() / 2)
                .attr('y', d => yScale(d.cardinality) - 10) // Position above bars but below x-axis labels
                .attr('text-anchor', 'middle')
                .attr('font-size', '11px')
                .attr('font-weight', 'bold')
                .attr('fill', '#333')
                .text(d => d.cardinality.toLocaleString());
            
            // Remove traditional x-axis (commented out)
            // g.append('g')
            //     .attr('transform', `translate(0, ${chartHeight})`)
            //     .call(d3.axisBottom(xScale))
            //     .selectAll('text')
            //     .attr('transform', 'rotate(-45)')
            //     .style('text-anchor', 'end')
            //     .style('font-size', '10px');
            
            // Y-axis
            g.append('g')
                .call(d3.axisLeft(yScale).tickFormat(d3.format(',.0f')))
                .selectAll('text')
                .style('font-size', '10px');
            
            // Y-axis label
            g.append('text')
                .attr('transform', 'rotate(-90)')
                .attr('y', 0 - margin.left + 30)
                .attr('x', 0 - (chartHeight / 2))
                .attr('dy', '1em')
                .style('text-anchor', 'middle')
                .style('font-size', '12px')
                .style('font-weight', 'bold')
                .text('Count');
            
            // Title removed to avoid duplication with container title
            
            // Legend
            const legend = svg.append('g')
                .attr('transform', `translate(${containerWidth - 150}, 40)`);
            
            const legendData = [
                { label: 'Single Set', color: colorScale(1) },
                { label: 'Two Sets', color: colorScale(2) },
                { label: 'Three Sets', color: colorScale(3) }
            ];
            
            legendData.forEach((item, i) => {
                const legendRow = legend.append('g')
                    .attr('transform', `translate(0, ${i * 20})`);
                
                legendRow.append('rect')
                    .attr('width', 12)
                    .attr('height', 12)
                    .attr('fill', item.color)
                    .attr('opacity', 0.8);
                
                legendRow.append('text')
                    .attr('x', 18)
                    .attr('y', 9)
                    .style('font-size', '11px')
                    .text(item.label);
            });
            
            // Create intersection matrix
            const matrixGroup = g.append('g')
                .attr('transform', `translate(0, ${matrixTop})`);
            
            // Define all possible sets
            const allSets = ['Time Overlap', 'Time Distance', 'In Service'];
            const dotRadius = 4;
            const lineWidth = 2;
            
            // Create matrix grid
            const matrixYScale = d3.scaleBand()
                .domain(allSets)
                .range([0, matrixHeight])
                .padding(0.2);
            
            // Add set labels on the left
            allSets.forEach((setName, i) => {
                matrixGroup.append('text')
                    .attr('x', -10)
                    .attr('y', matrixYScale(setName) + matrixYScale.bandwidth() / 2)
                    .attr('text-anchor', 'end')
                    .attr('dominant-baseline', 'middle')
                    .style('font-size', '11px')
                    .style('font-weight', 'bold')
                    .text(setName);
            });
            
            // Create intersection visualization for each data point
            sortedData.forEach((d, i) => {
                const xPos = xScale(d.name) + xScale.bandwidth() / 2;
                
                // Create dots for each set involved in this intersection
                const involvedSets = d.sets;
                const connectedDots = [];
                
                allSets.forEach(setName => {
                    const yPos = matrixYScale(setName) + matrixYScale.bandwidth() / 2;
                    const isInvolved = involvedSets.includes(setName);
                    
                    if (isInvolved) {
                        connectedDots.push({ x: xPos, y: yPos });
                    }
                    
                    // Draw dot
                    matrixGroup.append('circle')
                        .attr('cx', xPos)
                        .attr('cy', yPos)
                        .attr('r', dotRadius)
                        .attr('fill', isInvolved ? colorScale(d.setCount) : '#e0e0e0')
                        .attr('stroke', isInvolved ? '#333' : '#ccc')
                        .attr('stroke-width', isInvolved ? 1.5 : 0.5)
                        .attr('opacity', isInvolved ? 1 : 0.3);
                });
                
                // Draw connecting lines between involved sets
                if (connectedDots.length > 1) {
                    // Sort dots by y position for consistent line drawing
                    connectedDots.sort((a, b) => a.y - b.y);
                    
                    // Draw vertical line connecting all involved dots
                    const minY = connectedDots[0].y;
                    const maxY = connectedDots[connectedDots.length - 1].y;
                    
                    matrixGroup.append('line')
                        .attr('x1', xPos)
                        .attr('y1', minY)
                        .attr('x2', xPos)
                        .attr('y2', maxY)
                        .attr('stroke', colorScale(d.setCount))
                        .attr('stroke-width', lineWidth)
                        .attr('opacity', 0.8);
                }
            });
            
            // Add matrix title
            // matrixGroup.append('text')
            //     .attr('x', chartWidth / 2)
            //     .attr('y', -10)
            //     .attr('text-anchor', 'middle')
            //     .style('font-size', '12px')
            //     .style('font-weight', 'bold')
            //     .text('Set Intersections');
        }
        
        function createUpSetFallback(container, data) {
            let html = '<div class="text-center mb-4"><h4></h4></div>';
            html += '<div class="table-responsive"><table class="table table-striped">';
            html += '<thead><tr><th>Intersection</th><th>Count</th><th>Sets</th></tr></thead><tbody>';
            
            if (data.length === 0) {
                html += '<tr><td colspan="3" class="text-center text-muted">No data available</td></tr>';
            } else {
                data.forEach(item => {
                    const setsText = item.sets ? item.sets.join(', ') : item.name;
                    const countText = item.cardinality ? item.cardinality.toLocaleString() : 0;
                    
                    html += `<tr>
                        <td><strong>${item.name}</strong></td>
                        <td>${countText}</td>
                        <td><small class="text-muted">${setsText}</small></td>
                    </tr>`;
                });
            }
            
            html += '</tbody></table></div>';
            container.innerHTML = html;
        }
        
        function updateKPICards(data) {
            console.log('updateKPICards called with data:', data);
            
            // Extract data with proper fallbacks
            const recordCount = data.record_count || 0;
            const timeOverlap = (data.sets && data.sets[0] && data.sets[0].size) ? data.sets[0].size : 0;
            const timeDistance = (data.sets && data.sets[1] && data.sets[1].size) ? data.sets[1].size : 0;
            const inService = (data.sets && data.sets[2] && data.sets[2].size) ? data.sets[2].size : 0;
            const totalConflicts = data.total_conflicts || 0;

            console.log('KPI values:', { recordCount, timeOverlap, timeDistance, inService, totalConflicts });

            // Update KPI card values with animation
            const kpiElements = [
                { id: 'kpiRecordCount', value: recordCount },
                { id: 'kpiTimeOverlap', value: timeOverlap },
                { id: 'kpiTimeDistance', value: timeDistance },
                { id: 'kpiInService', value: inService },
                { id: 'kpiTotalConflicts', value: totalConflicts }
            ];

            kpiElements.forEach(kpi => {
                const element = document.getElementById(kpi.id);
                if (element) {
                    // Add animation effect
                    element.style.transform = 'scale(0.8)';
                    element.style.opacity = '0.5';
                    
                    setTimeout(() => {
                        element.textContent = Number(kpi.value).toLocaleString();
                        element.style.transform = 'scale(1)';
                        element.style.opacity = '1';
                    }, 150);
                }
            });

            // Show the KPI section after data is loaded
            const kpiSection = document.getElementById('kpiSection');
            if (kpiSection) {
                kpiSection.style.display = 'block';
                
                // Add fade-in animation
                kpiSection.style.opacity = '0';
                setTimeout(() => {
                    kpiSection.style.transition = 'opacity 0.5s ease-in-out';
                    kpiSection.style.opacity = '1';
                }, 100);
            }
        }
        
        function createFallbackVisualization(container, data) {
            // Create a simple table-based visualization as fallback
            let html = '<div class="text-center mb-4"><h4>Venn Diagram Data</h4></div>';
            html += '<div class="table-responsive"><table class="table table-striped">';
            html += '<thead><tr><th>Sets</th><th>Count</th><th>Description</th></tr></thead><tbody>';
            
            data.forEach(item => {
                const setsText = Array.isArray(item.sets) ? item.sets.join(' ∩ ') : item.sets;
                const countText = item.size ? item.size.toLocaleString() : 0;
                const description = item.description || '';
                
                html += `<tr>
                    <td><strong>${setsText}</strong></td>
                    <td>${countText}</td>
                    <td>${description}</td>
                </tr>`;
            });
            
            html += '</tbody></table></div>';
            
            container.innerHTML = html;
        }
        
        
        
        // Event handlers
        filterForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            showLoading();
            
            const formData = new FormData(filterForm);
            const filters = Object.fromEntries(formData.entries());
            
            // Date formats are already in yyyy-mm-dd format from the hidden date picker
            // No conversion needed
            
            // Remove empty values
            Object.keys(filters).forEach(key => {
                if (!filters[key]) {
                    delete filters[key];
                }
            });
            
            // Handle Select2 payer dropdown values manually
            const payerSelect = document.getElementById('payerId');
            if (payerSelect) {
                const selectedPayerIds = $(payerSelect).val();
                if (selectedPayerIds && selectedPayerIds.length > 0) {
                    // Filter out empty values
                    const validPayerIds = selectedPayerIds.filter(id => id !== '' && id !== null);
                    if (validPayerIds.length > 0) {
                        filters.payerId = validPayerIds;
                    }
                }
            }
            
            // Handle payer filter - exclude "All Payers" option
            if (filters.payerId) {
                if (Array.isArray(filters.payerId)) {
                    filters.payerId = filters.payerId.filter(id => id !== '');
                    if (filters.payerId.length === 0) {
                        delete filters.payerId;
                    }
                } else if (filters.payerId === '') {
                    delete filters.payerId;
                }
            }
            
            // If no payerId is set, it means "All Payers" is selected
            if (!filters.payerId || (Array.isArray(filters.payerId) && filters.payerId.length === 0)) {
                delete filters.payerId;
            }
            
            // Ensure metric is always included
            if (!filters.metricToShow) {
                filters.metricToShow = 'CO_TO';
            }
            
            console.log('Sending filters:', filters); // Debug log
            
            fetch('/new-payer-dashboard-venn/load-data', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrfToken
                },
                body: JSON.stringify(filters)
            })
            .then(response => response.json())
            .then(data => {
                console.log('Venn data response:', data);
                hideLoading();
                
                if (data.success) {
                    createVennDiagram(data.data);
                    createDoughnutChart(data.data); // Create doughnut chart instead of table
                    createUpSetChart(data.data); // Create UpSet chart with the same data
                    updateKPICards(data.data); // Update KPI cards with the same data
                    showMessage(data.message);
                    updateVennTitle(); // Update title after successful data loading
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
        
        // Setup hybrid date inputs with native picker and mm/dd/yyyy display
        function formatDateInputs() {
            // Setup dateFrom
            setupDateInput('dateFrom', 'dateFromDisplay');
            // Setup dateTo  
            setupDateInput('dateTo', 'dateToDisplay');
        }
        
        function setupDateInput(pickerId, displayId) {
            const picker = document.getElementById(pickerId);
            const display = document.getElementById(displayId);
            
            if (!picker || !display) return;
            
            // When date picker value changes, update the display field
            picker.addEventListener('change', function() {
                if (this.value) {
                    // Convert yyyy-mm-dd to mm/dd/yyyy for display
                    const date = new Date(this.value + 'T00:00:00');
                    const month = (date.getMonth() + 1).toString().padStart(2, '0');
                    const day = date.getDate().toString().padStart(2, '0');
                    const year = date.getFullYear();
                    display.value = `${month}/${day}/${year}`;
                } else {
                    display.value = '';
                }
            });
            
            // Handle input event as well for better browser compatibility
            picker.addEventListener('input', function() {
                if (this.value) {
                    // Convert yyyy-mm-dd to mm/dd/yyyy for display
                    const date = new Date(this.value + 'T00:00:00');
                    const month = (date.getMonth() + 1).toString().padStart(2, '0');
                    const day = date.getDate().toString().padStart(2, '0');
                    const year = date.getFullYear();
                    display.value = `${month}/${day}/${year}`;
                } else {
                    display.value = '';
                }
            });
            
            // Add keyboard support for clearing
            picker.addEventListener('keydown', function(e) {
                if (e.key === 'Backspace' || e.key === 'Delete') {
                    // Allow default behavior, then update display
                    setTimeout(() => {
                        if (!this.value) {
                            display.value = '';
                        }
                    }, 0);
                }
            });
            
            // Initialize display if picker has a value
            if (picker.value) {
                picker.dispatchEvent(new Event('change'));
            }
        }
        
        // Convert yyyy-mm-dd to mm/dd/yyyy for display
        function formatDateForDisplay(dateString) {
            if (!dateString) return '';
            
            const date = new Date(dateString + 'T00:00:00');
            if (isNaN(date.getTime())) return '';
            
            const month = (date.getMonth() + 1).toString().padStart(2, '0');
            const day = date.getDate().toString().padStart(2, '0');
            const year = date.getFullYear();
            
            return `${month}/${day}/${year}`;
        }
        
        // The date picker already provides yyyy-mm-dd format for backend
        function formatDateForBackend(dateString) {
            // Since we're using the native date picker, it already provides the correct format
            return dateString;
        }
        
        // Load initial data
        document.addEventListener('DOMContentLoaded', function() {
            // Initialize date input formatting
            formatDateInputs();
            // filterForm.dispatchEvent(new Event('submit')); // Removed automatic data loading
        });
    </script>
</body>
</html>
