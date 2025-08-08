<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Payer Dashboard - Venn Diagram</title>
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
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h4 class="my-2">New Payer Dashboard - Venn Diagram</h4>
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
                        <div class="row">
                            <div class="col-md-2">
                                <label for="metricToShow" class="form-label">Metric to Show</label>
                                <select class="form-select form-select-sm" id="metricToShow" name="metricToShow">
                                    <option value="CO_TO" selected>Conflict Count</option>
                                    <option value="CO_OP">Conflict $ Impact</option>
                                    <option value="CO_FP">Final $ Impact</option>
                                </select>
                            </div>
                            
                            <div class="col-md-2">
                                <label for="dateFrom" class="form-label">Date From</label>
                                <input type="date" class="form-control form-control-sm" id="dateFrom" name="dateFrom">
                            </div>
                            
                            <div class="col-md-2">
                                <label for="dateTo" class="form-label">Date To</label>
                                <input type="date" class="form-control form-control-sm" id="dateTo" name="dateTo">
                            </div>
                            
                            <div class="col-md-2">
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
                            
                            <div class="col-md-2">
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
                            
                            <div class="col-md-2">
                                <label for="statusFlag" class="form-label">Status Flag</label>
                                <select class="form-select form-select-sm" id="statusFlag" name="statusFlag">
                                    <option value="">All Status Flags</option>
                                    @if(isset($filterOptions['statusFlags']))
                                        @foreach($filterOptions['statusFlags'] as $statusFlag)
                                            <option value="{{ $statusFlag }}">{{ $statusFlag }}</option>
                                        @endforeach
                                    @endif
                                </select>
                            </div>
                            
                            <div class="col-md-2">
                                <label for="payerId" class="form-label">Payer</label>
                                <select class="form-select form-select-sm" id="payerId" name="payerId[]" multiple>
                                    @if(isset($payerOptions))
                                        @foreach($payerOptions as $payer)
                                            <option value="{{ $payer['id'] }}">{{ $payer['name'] }}</option>
                                        @endforeach
                                    @endif
                                </select>
                            </div>
                            
                            <div class="col-md-2 d-flex align-items-end">
                                <button type="submit" class="btn btn-primary btn-sm" aria-label="Apply Filters">
                                    <i class="fas fa-search"></i>
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
                
                

                <!-- Loading Spinner -->
                <div id="loadingSpinner" class="loading-spinner">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="mt-2">Loading Venn diagram data...</p>
                </div>
                
                <!-- Venn Diagram Container -->
                <div class="row">
                    <div class="col-md-6">
                        <div class="venn-container" id="vennContainer">
                            <h5 class="section-title" id="vennTitle">Conflict by Type</h5>
                            <div id="vennDiagram"></div>
                            <div id="vennTooltip" class="venn-tooltip"></div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="venn-data-container">
                            <h5 class="section-title">Underlying Data</h5>
                            <div id="vennDataTable" class="table-responsive">
                                <table class="table table-sm table-striped">
                                    <colgroup>
                                        <col style="width: 60%">
                                        <col style="width: 40%">
                                    </colgroup>
                                    <tbody id="vennDataTableBody">
                                        <tr>
                                            <td colspan="2" class="text-center text-muted">No data loaded. Please apply filters to view data.</td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
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
        
        // Initialize Select2 for payer dropdown
        $(document).ready(function() {
            $('#payerId').select2({
                theme: 'bootstrap-5',
                placeholder: 'All Payers',
                allowClear: true,
                width: '100%'
            });
        });
        
        function showLoading() {
            loadingSpinner.style.display = 'block';
            vennContainer.style.display = 'none';
            
            
            // Show loading in data table
            const tableBody = document.getElementById('vennDataTableBody');
            if (tableBody) {
                tableBody.innerHTML = '<tr><td colspan="2" class="text-center text-muted">Loading data...</td></tr>';
            }
        }
        
        function hideLoading() {
            loadingSpinner.style.display = 'none';
            vennContainer.style.display = 'block';
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
        
        function updateVennDataTable(data) {
            console.log('updateVennDataTable called with data:', data);
            const tableBody = document.getElementById('vennDataTableBody');
            
            if (!tableBody) {
                console.error('Table body not found');
                return;
            }
            
            // Extract data with proper fallbacks
            const recordCount = data.record_count || 0;
            const timeOverlap = (data.sets && data.sets[0] && data.sets[0].size) ? data.sets[0].size : 0;
            const timeDistance = (data.sets && data.sets[1] && data.sets[1].size) ? data.sets[1].size : 0;
            const inService = (data.sets && data.sets[2] && data.sets[2].size) ? data.sets[2].size : 0;
            const totalConflicts = data.total_conflicts || 0;

            console.log('Extracted values:', { recordCount, timeOverlap, timeDistance, inService, totalConflicts });

            const rows = [
                { label: 'Record Count', value: recordCount },
                { label: 'Time Overlap', value: timeOverlap },
                { label: 'Time Distance', value: timeDistance },
                { label: 'In Service', value: inService },
                { label: 'Total', value: totalConflicts }
            ];

            let html = '';
            rows.forEach(r => {
                html += `<tr>
                    <td style="color: #000000 !important; font-weight: bold !important; font-size: 14px !important; padding: 12px 14px !important;">${r.label}</td>
                    <td><span class="badge bg-secondary">${Number(r.value).toLocaleString()}</span></td>
                </tr>`;
            });

            console.log('Generated HTML:', html);
            tableBody.innerHTML = html;
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
                    updateVennDataTable(data.data);
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
        
        // Load initial data
        document.addEventListener('DOMContentLoaded', function() {
            // filterForm.dispatchEvent(new Event('submit')); // Removed automatic data loading
        });
    </script>
</body>
</html>
