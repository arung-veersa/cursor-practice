<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Snowflake Data Viewer</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            font-weight: 300;
        }

        .header p {
            font-size: 1.1rem;
            opacity: 0.9;
        }

        .content {
            padding: 30px;
        }

        .load-section {
            text-align: center;
            margin-bottom: 30px;
        }

        .load-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 1.1rem;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .load-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.6);
        }

        .load-btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }

        .loading {
            display: none;
            margin-top: 20px;
        }

        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .message {
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            display: none;
        }

        .message.success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }

        .message.error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }

        .table-container {
            margin-top: 30px;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            display: none;
        }

        .data-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
        }

        .data-table th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }

        .data-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }

        .data-table tr:hover {
            background-color: #f8f9fa;
        }

        .data-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }

        .no-data {
            text-align: center;
            padding: 40px;
            color: #666;
            font-style: italic;
        }

        @media (max-width: 768px) {
            .container {
                margin: 10px;
                border-radius: 10px;
            }

            .header {
                padding: 20px;
            }

            .header h1 {
                font-size: 2rem;
            }

            .content {
                padding: 20px;
            }

            .data-table {
                font-size: 0.9rem;
            }

            .data-table th,
            .data-table td {
                padding: 8px 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>❄️ Snowflake Data Viewer</h1>
            <p>Connect and view data from your Snowflake database</p>
        </div>

        <div class="content">
            <div class="load-section">
                <button class="load-btn" onclick="loadData()">
                    📊 Load Data
                </button>
                
                <div class="loading">
                    <div class="spinner"></div>
                    <p style="margin-top: 10px; color: #666;">Loading data from Snowflake...</p>
                </div>
            </div>

            <div class="message" id="message"></div>

            <div class="table-container" id="tableContainer">
                <table class="data-table" id="dataTable">
                    <thead>
                        <tr id="tableHeader">
                            <!-- Headers will be dynamically generated -->
                        </tr>
                    </thead>
                    <tbody id="tableBody">
                        <!-- Data will be dynamically generated -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        function showMessage(message, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.textContent = message;
            messageDiv.className = `message ${type}`;
            messageDiv.style.display = 'block';
            
            setTimeout(() => {
                messageDiv.style.display = 'none';
            }, 5000);
        }

        function loadData() {
            const loadBtn = document.querySelector('.load-btn');
            const loading = document.querySelector('.loading');
            const tableContainer = document.getElementById('tableContainer');

            // Disable button and show loading
            loadBtn.disabled = true;
            loadBtn.textContent = 'Loading...';
            loading.style.display = 'block';
            tableContainer.style.display = 'none';

            // Make AJAX request
            fetch('/load-data', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displayData(data.data);
                    showMessage(data.message, 'success');
                } else {
                    showMessage(data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showMessage('An error occurred while loading data', 'error');
            })
            .finally(() => {
                // Re-enable button and hide loading
                loadBtn.disabled = false;
                loadBtn.textContent = '📊 Load Data';
                loading.style.display = 'none';
            });
        }

        function displayData(data) {
            const tableContainer = document.getElementById('tableContainer');
            const tableHeader = document.getElementById('tableHeader');
            const tableBody = document.getElementById('tableBody');

            if (!data || data.length === 0) {
                tableBody.innerHTML = '<tr><td colspan="100%" class="no-data">No data available</td></tr>';
                tableContainer.style.display = 'block';
                return;
            }

            // Generate headers
            const headers = Object.keys(data[0]);
            tableHeader.innerHTML = headers.map(header => 
                `<th>${header.charAt(0).toUpperCase() + header.slice(1).replace(/_/g, ' ')}</th>`
            ).join('');

            // Generate rows
            tableBody.innerHTML = data.map(row => 
                `<tr>${headers.map(header => 
                    `<td>${row[header] !== null ? row[header] : '<em>null</em>'}</td>`
                ).join('')}</tr>`
            ).join('');

            tableContainer.style.display = 'block';
        }
    </script>
</body>
</html> 