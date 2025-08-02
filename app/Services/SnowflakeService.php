<?php

namespace App\Services;

use PDO;
use PDOException;
use Illuminate\Support\Facades\Log;

class SnowflakeService
{
    private $connection;
    private $config;
    private $sessionToken;

    public function __construct()
    {
        $this->config = [
            'host' => env('SNOWFLAKE_HOST'),
            'account' => env('SNOWFLAKE_ACCOUNT'),
            'username' => env('SNOWFLAKE_USERNAME'),
            'password' => env('SNOWFLAKE_PASSWORD'),
            'database' => env('SNOWFLAKE_DATABASE', 'CONFLICTREPORT_SANDBOX'),
            'schema' => env('SNOWFLAKE_SCHEMA', 'PUBLIC'),
            'warehouse' => env('SNOWFLAKE_WAREHOUSE'),
            'role' => env('SNOWFLAKE_ROLE'),
            'mfa_token' => env('SNOWFLAKE_MFA_TOKEN'), // MFA token (TOTP, SMS code, etc.)
            'private_key' => env('SNOWFLAKE_PRIVATE_KEY'), // Path to private key file
            'auth_method' => env('SNOWFLAKE_AUTH_METHOD', 'password'), // password, keypair, mfa
            'ssl_verify' => env('SNOWFLAKE_SSL_VERIFY', 'true'), // SSL verification setting
            'ssl_cert_path' => env('SNOWFLAKE_SSL_CERT_PATH'), // Custom SSL certificate path
            'dsn' => env('SNOWFLAKE_ODBC_DSN'), // Added for DSN support
        ];
    }

    public function connect()
    {
        try {
            $authMethod = $this->config['auth_method'];
            
            if ($authMethod === 'keypair') {
                return $this->connectWithKeyPair();
            } elseif ($authMethod === 'mfa') {
                return $this->connectWithMFA();
            } else {
                return $this->connectWithPassword();
            }
        } catch (PDOException $e) {
            Log::error('Snowflake connection failed: ' . $e->getMessage());
            return false;
        }
    }

    private function connectWithKeyPair()
    {
        $account = $this->config['account'];
        $username = $this->config['username'];
        $privateKeyPath = $this->config['private_key'];
        $warehouse = $this->config['warehouse'];
        $database = $this->config['database'];
        $schema = $this->config['schema'];
        $role = $this->config['role'];

        // Validate required parameters
        if (!$privateKeyPath || !file_exists($privateKeyPath)) {
            throw new \Exception("Private key file not found: {$privateKeyPath}");
        }

        // Generate JWT token for authentication
        $jwt = $this->generateJWTToken($account, $username, $privateKeyPath);

        // Build ODBC connection string
        $dsnName = $this->config['dsn'] ?? 'SnowflakeDSIIDriver';
        
        // Use DSN if available, otherwise use driver string
        if ($this->config['dsn']) {
            $dsn = "odbc:DSN={$dsnName};Database={$database};Schema={$schema};Warehouse={$warehouse}";
        } else {
            $dsn = "odbc:Driver={{$dsnName}};Server={$account}.snowflakecomputing.com;Database={$database};Schema={$schema};Warehouse={$warehouse}";
        }
        
        if ($role) {
            $dsn .= ";Role={$role}";
        }

        // Connect using JWT as password
        $this->connection = new PDO($dsn, $username, $jwt, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_TIMEOUT => 30,
            PDO::ATTR_CURSOR => PDO::CURSOR_FWDONLY, // Use forward-only cursor for ODBC compatibility
        ]);

        Log::info('Successfully connected to Snowflake using keypair authentication');
        return true;
    }

    private function connectWithPassword()
    {
        $account = $this->config['account'];
        $username = $this->config['username'];
        $password = $this->config['password'];
        $warehouse = $this->config['warehouse'];
        $database = $this->config['database'];
        $schema = $this->config['schema'];
        $role = $this->config['role'];

        // Build ODBC connection string
        $dsnName = $this->config['dsn'] ?? 'SnowflakeDSIIDriver';
        
        // Use DSN if available, otherwise use driver string
        if ($this->config['dsn']) {
            $dsn = "odbc:DSN={$dsnName};Database={$database};Schema={$schema};Warehouse={$warehouse}";
        } else {
            $dsn = "odbc:Driver={{$dsnName}};Server={$account}.snowflakecomputing.com;Database={$database};Schema={$schema};Warehouse={$warehouse}";
        }
        
        if ($role) {
            $dsn .= ";Role={$role}";
        }

        $this->connection = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_TIMEOUT => 30,
            PDO::ATTR_CURSOR => PDO::CURSOR_FWDONLY, // Use forward-only cursor for ODBC compatibility
        ]);

        Log::info('Successfully connected to Snowflake using password authentication');
        return true;
    }

    private function connectWithMFA()
    {
        $username = $this->config['username'];
        $password = $this->config['password'];
        $mfaToken = $this->config['mfa_token'];
        $dsnName = $this->config['dsn'] ?? 'SnowflakeDSIIDriver';

        // Build DSN connection string
        $dsn = "odbc:DSN={$dsnName}";

        // For MFA, we need to handle the authentication differently
        // The ODBC driver will prompt for MFA token during connection
        $this->connection = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_TIMEOUT => 30,
            PDO::ATTR_CURSOR => PDO::CURSOR_FWDONLY, // Use forward-only cursor for ODBC compatibility
        ]);

        Log::info('Successfully connected to Snowflake using MFA authentication');
        return true;
    }

    private function generateJWTToken($account, $username, $privateKeyPath)
    {
        // Read private key
        $privateKey = file_get_contents($privateKeyPath);
        if (!$privateKey) {
            throw new \Exception("Failed to read private key file: {$privateKeyPath}");
        }

        // Validate private key format
        if (!openssl_pkey_get_private($privateKey)) {
            throw new \Exception("Invalid private key format: " . openssl_error_string());
        }

        // Generate JWT token
        $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
        $payload = json_encode([
            'iss' => $account . '.' . $username,
            'sub' => $account . '.' . $username,
            'iat' => time(),
            'exp' => time() + 3600 // 1 hour expiration
        ]);

        $base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
        $base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
        
        $signature = '';
        if (!openssl_sign($base64Header . "." . $base64Payload, $signature, $privateKey, 'SHA256')) {
            throw new \Exception("Failed to sign JWT token: " . openssl_error_string());
        }
        
        $base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        return $base64Header . "." . $base64Payload . "." . $base64Signature;
    }

    public function query($sql)
    {
        try {
            if (!$this->connection) {
                if (!$this->connect()) {
                    throw new \Exception('Failed to connect to Snowflake');
                }
            }

            // Use query() instead of prepare() to avoid ODBC cursor library issues
            $stmt = $this->connection->query($sql);
            
            if (!$stmt) {
                throw new \Exception('Query execution failed');
            }
            
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (PDOException $e) {
            Log::error('Snowflake query failed: ' . $e->getMessage());
            throw new \Exception('Query execution failed: ' . $e->getMessage());
        }
    }

    public function getSettingsData()
    {
        // Use PDO ODBC connection
        return $this->query("SELECT * FROM CONFLICTREPORT_SANDBOX.PUBLIC.SETTINGS");
    }

    public function disconnect()
    {
        $this->connection = null;
        $this->sessionToken = null;
    }

    // REST API method for Snowflake connection with MFA support
    public function queryViaRest($sql)
    {
        try {
            $account = $this->config['account'];
            $warehouse = $this->config['warehouse'];
            $database = $this->config['database'];
            $schema = $this->config['schema'];

            // Get authentication token based on method
            $authToken = $this->getAuthToken();

            $url = "https://{$account}.snowflakecomputing.com/api/v2/statements";
            
            $data = [
                'statement' => $sql,
                'timeout' => 60,
                'database' => $database,
                'schema' => $schema,
                'warehouse' => $warehouse
            ];

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Accept: application/json',
                'Authorization: ' . $authToken
            ]);
            
            // Configure SSL settings
            $this->configureSSL($ch);
            
            curl_setopt($ch, CURLOPT_TIMEOUT, 60);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $error = curl_error($ch);
            curl_close($ch);

            if ($error) {
                // Check if it's an SSL error and provide helpful guidance
                if (strpos($error, 'SSL') !== false || strpos($error, 'certificate') !== false) {
                    throw new \Exception("SSL Error: {$error}. Try setting SNOWFLAKE_SSL_VERIFY=false in your .env file for development, or configure proper SSL certificates for production.");
                }
                throw new \Exception("cURL Error: {$error}");
            }

            if ($httpCode !== 200) {
                throw new \Exception("HTTP Error: {$httpCode} - Response: {$response}");
            }

            $result = json_decode($response, true);
            
            if (isset($result['data'])) {
                return $result['data'];
            } else {
                throw new \Exception('Invalid response format: ' . $response);
            }
        } catch (\Exception $e) {
            Log::error('Snowflake REST API query failed: ' . $e->getMessage());
            throw new \Exception('REST API query failed: ' . $e->getMessage());
        }
    }

    // Configure SSL settings for cURL
    private function configureSSL($ch)
    {
        $sslVerify = filter_var($this->config['ssl_verify'], FILTER_VALIDATE_BOOLEAN);
        $sslCertPath = $this->config['ssl_cert_path'];

        if ($sslVerify) {
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
            
            // Use custom certificate path if provided
            if ($sslCertPath && file_exists($sslCertPath)) {
                curl_setopt($ch, CURLOPT_CAINFO, $sslCertPath);
                Log::info("Using custom SSL certificate: {$sslCertPath}");
            }
        } else {
            // Disable SSL verification (for development only)
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
            Log::warning("SSL verification disabled - this should only be used for development");
        }
    }

    // Get authentication token based on configured method
    private function getAuthToken()
    {
        $authMethod = $this->config['auth_method'];

        switch ($authMethod) {
            case 'keypair':
                return $this->getKeyPairToken();
            case 'mfa':
                return $this->getMFAToken();
            case 'password':
            default:
                return $this->getBasicAuthToken();
        }
    }

    // Basic username/password authentication
    private function getBasicAuthToken()
    {
        $username = $this->config['username'];
        $password = $this->config['password'];
        
        if (!$username || !$password) {
            throw new \Exception('Username and password are required for basic authentication');
        }
        
        return 'Basic ' . base64_encode("{$username}:{$password}");
    }

    // Key pair authentication for users with MFA disabled
    private function getKeyPairToken()
    {
        $privateKeyPath = $this->config['private_key'];
        $username = $this->config['username'];
        $account = $this->config['account'];

        // Validate required parameters
        if (!$privateKeyPath) {
            throw new \Exception('Private key path is required for key pair authentication');
        }
        if (!$username) {
            throw new \Exception('Username is required for key pair authentication');
        }
        if (!$account) {
            throw new \Exception('Account is required for key pair authentication');
        }

        // Check if private key file exists
        if (!file_exists($privateKeyPath)) {
            throw new \Exception("Private key file not found: {$privateKeyPath}");
        }

        // Check file permissions (should be 600)
        $perms = fileperms($privateKeyPath);
        $perms_octal = substr(sprintf('%o', $perms), -4);
        if ($perms_octal !== '0600') {
            Log::warning("Private key file permissions are {$perms_octal}, should be 0600 for security");
        }

        // Read private key
        $privateKey = file_get_contents($privateKeyPath);
        if (!$privateKey) {
            throw new \Exception("Failed to read private key file: {$privateKeyPath}");
        }

        // Validate private key format
        if (!openssl_pkey_get_private($privateKey)) {
            throw new \Exception("Invalid private key format: " . openssl_error_string());
        }

        // Generate JWT token
        $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
        $payload = json_encode([
            'iss' => $account . '.' . $username,
            'sub' => $account . '.' . $username,
            'iat' => time(),
            'exp' => time() + 3600 // 1 hour expiration
        ]);

        $base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
        $base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
        
        $signature = '';
        if (!openssl_sign($base64Header . "." . $base64Payload, $signature, $privateKey, 'SHA256')) {
            throw new \Exception("Failed to sign JWT token: " . openssl_error_string());
        }
        
        $base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        $jwt = $base64Header . "." . $base64Payload . "." . $base64Signature;
        
        return 'Bearer ' . $jwt;
    }

    // MFA authentication
    private function getMFAToken()
    {
        // If we already have a session token, use it
        if ($this->sessionToken) {
            return 'Bearer ' . $this->sessionToken;
        }

        $account = $this->config['account'];
        $username = $this->config['username'];
        $password = $this->config['password'];
        $mfaToken = $this->config['mfa_token'];

        if (!$mfaToken) {
            throw new \Exception('MFA token is required for MFA authentication');
        }

        // Login with MFA
        $loginUrl = "https://{$account}.snowflakecomputing.com/api/v2/session/login";
        $loginData = [
            'data' => [
                'CLIENT_APP_ID' => 'PHP_LARAVEL_APP',
                'CLIENT_APP_VERSION' => '1.0.0',
                'LOGIN_NAME' => $username,
                'PASSWORD' => $password,
                'AUTHENTICATOR' => 'snowflake',
                'MFA_TOKEN' => $mfaToken
            ]
        ];

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $loginUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($loginData));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Accept: application/json'
        ]);
        
        // Configure SSL settings
        $this->configureSSL($ch);
        
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($error) {
            // Check if it's an SSL error and provide helpful guidance
            if (strpos($error, 'SSL') !== false || strpos($error, 'certificate') !== false) {
                throw new \Exception("SSL Error during MFA login: {$error}. Try setting SNOWFLAKE_SSL_VERIFY=false in your .env file for development.");
            }
            throw new \Exception("MFA login failed: {$error}");
        }

        if ($httpCode !== 200) {
            throw new \Exception("MFA login failed: HTTP {$httpCode} - {$response}");
        }

        $result = json_decode($response, true);
        if (isset($result['data']['sessionToken'])) {
            $this->sessionToken = $result['data']['sessionToken'];
            return 'Bearer ' . $this->sessionToken;
        } else {
            throw new \Exception('Failed to get session token from MFA login');
        }
    }
} 