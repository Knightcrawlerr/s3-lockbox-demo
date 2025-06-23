<?php
require 'config.php';

$userId = $_POST['user_id'] ?? '';
$enc = $_POST['enc'] ?? 'sse';
$file = $_FILES['file'];

if (!$userId || !$file || $file['error']) {
    die("❌ Invalid input or file error");
}

// Validate file type/extension
$allowedTypes = ['image/jpeg', 'image/png', 'application/pdf'];
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($file['type'], $allowedTypes) || !in_array($ext, ['jpg', 'jpeg', 'png', 'pdf'])) {
    die("❌ Invalid file type");
}

// Move to temp
$tmpPath = "$tempDir/" . basename($file['name']);
move_uploaded_file($file['tmp_name'], $tmpPath);

// Metadata
$meta = ['uploaded_by' => $userId];
$keyPrefix = $enc === 'sse' ? 'sse-upload/' : 'client-upload/';
$originalName = basename($file['name']);
$uniqueId = uniqid();
$folder = $enc === 'sse' ? 'sse-upload' : 'client-upload';
$key = "$folder/$userId/{$uniqueId}_{$originalName}";

try {
    if ($enc === 'client') {
        // Simple XOR encryption (demo only — use proper crypto in real life)
        //$data = file_get_contents($tmpPath);
        $encryptionkey = hash('sha256', 'EfLffDNuZP2dr0wwRD8HtmFeIDZOv7a6yrZZ+UvOqBNL3w96q3Z2AlhcBzn+dqvC', true); // Ideally from ENV
        $iv = openssl_random_pseudo_bytes(16); // AES block size is 16 bytes
        $encData = openssl_encrypt(file_get_contents($tmpPath), 'AES-256-CBC', $encryptionkey, OPENSSL_RAW_DATA, $iv);
        file_put_contents($tmpPath, $iv . $encData);  // Save IV + encrypted data
    }

    $params = [
        'Bucket' => $bucket,
        'Key' => $key,
        'SourceFile' => $tmpPath,
        'Metadata' => $meta
    ];

    if ($enc === 'sse') {
        $params['ServerSideEncryption'] = 'AES256';
    }

    $s3->putObject($params);

    echo "✅ Uploaded to S3: $key<br>";
    echo "<a href='view_uploads.php'>View Uploaded Files</a>";
} catch (Exception $e) {
    echo "❌ Upload failed: " . $e->getMessage();
} finally {
    @unlink($tmpPath);
}

