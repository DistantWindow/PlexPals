# Define the path to mkvmerge
$mkvmergePath = "F:\Programs\MKVToolNix\mkvmerge.exe"

# Get the current working directory
$currentDirectory = Get-Location

# Get all the mp4 and srt files in the current directory
$videoFiles = Get-ChildItem -Path $currentDirectory -Filter "*.mp4"
$subtitles = Get-ChildItem -Path $currentDirectory -Filter "*.srt"

# Iterate over the mp4 files
foreach ($videoFile in $videoFiles) {
    # Get the base name of the mp4 file (without the extension)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($videoFile.Name)

    # Get the matching subtitle files
    $matchingSubtitles = $subtitles | Where-Object { $_.BaseName -like "*$baseName*" }

    # Check if any matching subtitle files were found
    if ($matchingSubtitles) {
        # Create the output MKV file path
        $outputFileNoQ = "$($baseName).mkv"
        $outputFile = "`"$($outputFileNoQ)`""

        $inputFile += "`"$($videoFile.Name)`""

        # Build the argument list for mkvmerge
        $arguments = @("-o", $outputFile, $inputFile)
         foreach ($subtitle in $matchingSubtitles) {
            $subFile = "`"$($subtitle.Name)`""

            $arguments += $subFile           
        }
        $arguments += "--default-language en --language 1:en"

        # Execute the mkvmerge command to remux the files
        
        $mergeCommand = "$($mkvmergePath) $($arguments)"
        Write-Host $mergeCommand
        #Start-Process -FilePath $mkvmergePath -ArgumentList $arguments -Wait
        
} 
else 
{
 write-host "No subtitles found"
  }}
if (Test-Path -Path $outputFileNoQ -PathType Leaf)
        {
        Write-Host "Remuxed files: $($videoFile.Name), $($matchingSubtitles.Count) subtitles => $outputFile"
    } else {
        Write-Host "Ran into some issue with the arguments for this file - " 
        Write-Host $arguments
    }