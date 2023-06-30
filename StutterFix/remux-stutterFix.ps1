clear-host
# Define the path to mkvmerge
$mkvmergePath = "F:\Programs\MKVToolNix\mkvmerge.exe"

# Get the current working directory
$currentDirectory = Get-Location

# Get all the mp4 and srt files in the current directory
$videoFiles = Get-ChildItem -Path $currentDirectory -Filter "*.mp4"
$subtitles = Get-ChildItem -Path $currentDirectory -Filter "*.srt"

# Iterate over the mp4 files
foreach ($videoFile in $videoFiles) {
    #reset the arguments
    $arguments = $null
    $mergeCommand = $null

    # Get the base name of the mp4 file (without the extension)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($videoFile.Name)

     # Create the output MKV file path
        $outputFileNoQ = "$($baseName).mkv"
        $outputFile = "`"$($outputFileNoQ)`""

        $inputFile = "`"$($videoFile.Name)`""
        $arguments = @("-o", $outputFile, $inputFile)
        write-host "args "$arguments


    # Get the matching subtitle files
    $matchingSubtitles = $subtitles | Where-Object { $_.BaseName -like "*$baseName*" }

    # Check if any matching subtitle files were found
    if ($matchingSubtitles) {
       
        # Build the argument list for mkvmerge
       
         foreach ($subtitle in $matchingSubtitles) {
            $subFile = "`"$($subtitle.Name)`""

            $arguments += $subFile           
        }
        $arguments += "--default-language en --language 1:en"        
        } 
          else 
            {
            write-host "No subtitles found"
          }

# Execute the mkvmerge command to remux the files
$mergeCommand = "$($mkvmergePath) $($arguments)"
Write-Host $mergeCommand
Start-Process -FilePath $mkvmergePath -ArgumentList $arguments -Wait

if (Test-Path -Path $outputFileNoQ -PathType Leaf)
        {
        Write-Host "Remuxed files: $($videoFile.Name), $($matchingSubtitles.Count) subtitles => $outputFile"
    } else {
        Write-Host "Ran into some issue with the arguments for this file - " 
        Write-Host $arguments
    }
}

