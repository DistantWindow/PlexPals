function Compare-VideoDurations {
    param (
        [string]$inputPath,
        [string]$outputPath
    )

    # Check if ffprobe is available
    #if (-not (Test-Path 'ffprobe')) {
     #   Write-Host "Error: ffprobe is not found. Please make sure it's installed and in the system PATH." -ForegroundColor Red
      #  return
    #}

    # Get duration of input video
    $inputDuration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath

    # Get duration of output video
    $outputDuration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $outputPath

    # Compare durations
    if ($inputDuration -eq $outputDuration) {
        Write-Host "The durations are equal: $($inputDuration) seconds." -ForegroundColor Green
    } else {
        Write-Host "The durations are not equal." -ForegroundColor Red
        Write-Host "Input video duration: $($inputDuration) seconds" -ForegroundColor Yellow
        Write-Host "Output video duration: $($outputDuration) seconds" -ForegroundColor Yellow
    }
}

# Example usage
$inputFile = "J:\Utilities\Transcode\singles\out\test.mkv"
$outputFile = "J:\Utilities\Transcode\singles\out\test.mkv"
Compare-VideoDurations -inputPath $inputFile -outputPath $outputFile
