<?php
require 'config.php';

$key = $_GET['key'] ?? '';
if (!$key) die("❌ No key");

$tmpPath = "$tempDir/" . basename($key);

try {
    $result = $s3->getObject([
        'Bucket' => $bucket,
        'Key' => $key,
        'SaveAs' => $tmpPath
    ]);

    // If client-encrypted, decode it
    if (strpos($key, 'client-upload/') === 0) {
	$encryptionkey = hash('sha256', 'EfLffDNuZP2dr0wwRD8HtmFeIDZOv7a6yrZZ+UvOqBNL3w96q3Z2AlhcBzn+dqvC', true);
	$data = file_get_contents($tmpPath);
	$iv = substr($data, 0, 16);
	$encBody = substr($data, 16);
	$dec = openssl_decrypt($encBody, 'AES-256-CBC', $encryptionkey, OPENSSL_RAW_DATA, $iv);
	file_put_contents($tmpPath, $dec);    
    }

    // Serve file
    header('Content-Type: ' . mime_content_type($tmpPath));
    header('Content-Disposition: inline; filename="' . basename($tmpPath) . '"');
    readfile($tmpPath);

    // Auto-delete after N minutes using `at` (if installed)
    exec("echo 'rm \"$tmpPath\"' | at now + 2 minutes");
} catch (Exception $e) {
    echo "❌ Download error: " . $e->getMessage();
}

