<!DOCTYPE html>
<html>
<head><title>Secure Upload</title></head>
<body>
  <h2>Upload File</h2>
  <form action="upload.php" method="POST" enctype="multipart/form-data">
    Username/ID: <input type="text" name="user_id" required><br><br>
    Select File: <input type="file" name="file" required><br><br>
    Encryption Method:
    <label><input type="radio" name="enc" value="sse" checked> SSE (AWS-managed)</label>
    <label><input type="radio" name="enc" value="client"> Client-side Encryption</label><br><br>
    <button type="submit">Upload</button>
  </form>

  <p><a href="view_uploads.php">View Uploaded Files</a></p>
</body>
</html>

