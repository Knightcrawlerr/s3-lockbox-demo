<?php
require 'config.php';

$user = $_GET['user'] ?? '';
if (!$user) {
    echo "<form method='get'>Enter Username/ID: <input name='user'><button type='submit'>Search</button></form>";
    exit;
}

$prefixes = ['sse-upload/' . $user . '/', 'client-upload/' . $user . '/'];
foreach ($prefixes as $prefix) {
    echo "<h3>$prefix</h3>";
    try {
        $results = $s3->listObjectsV2([
            'Bucket' => $bucket,
            'Prefix' => $prefix
        ]);
        if (!empty($results['Contents'])) {
            echo "<ul>";
            foreach ($results['Contents'] as $obj) {
                $key = $obj['Key'];
                $url = "download.php?key=" . urlencode($key);
                echo "<li><a href='$url'>" . htmlspecialchars(basename($key)) . "</a></li>";
            }
            echo "</ul>";
        } else {
            echo "No files found.";
        }
    } catch (Exception $e) {
        echo "Error listing files: " . $e->getMessage();
    }
}

