<?php
require 'aws.phar';

use Aws\S3\S3Client;

$region = 'us-east-1';
$bucket = 'demo-s3-pii';
$tempDir = __DIR__ . '/temp';

// AWS S3 client
$s3 = new S3Client([
    'version' => 'latest',
    'region' => $region
]);

// Create temp directory if not exists
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0750, true);
}

