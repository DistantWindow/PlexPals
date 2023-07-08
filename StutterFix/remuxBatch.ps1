clear-host
# Define the path to mkvmerge
$mkvmergePath = "F:\Programs\MKVToolNix\mkvmerge.exe"
$batchPath = "J:\Utilities\remuxList.txt"

# Get the current working directory
(get-content $batchPath)| ForEach-Object {
$errorCount= 0
$currentDirectory = $_
write-host $currentDirectory

# Get all the mp4 and srt files in the current directory
$videoFiles = Get-ChildItem -Path $currentDirectory -Filter "*.mp4"
$subtitles = Get-ChildItem -Path $currentDirectory -Filter "*.srt"

# Iterate over the mp4 files
foreach ($videoFile in $videoFiles) {
    #reset the arguments
    $arguments = $null
    $mergeCommand = $null
    write-host $videoFile
   
    # Get the base name of the mp4 file (without the extension)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($videoFile.Name)


     # Create the output MKV file path
        $outputFileNoQ = "$($baseName).mkv"
        $outputPathNoQ = Join-Path $currentDirectory $outputFileNoQ
        $outputFile = "`"$($outputPathNoQ)`""

        $inputFileNoQ = $videoFile.Name
        $inputPathNoQ = Join-Path $currentDirectory $inputFileNoQ
        $inputFile = "`"$($inputPathNoQ)`""
        $arguments = @("-o", $outputFile, $inputFile)
        write-host "args "$arguments


    # Get the matching subtitle files
    $matchingSubtitles = $subtitles | Where-Object { $_.BaseName -like "*$baseName*" }

    # Check if any matching subtitle files were found
    if ($matchingSubtitles) {
       
        # Build the argument list for mkvmerge
       
         foreach ($subtitle in $matchingSubtitles) {
            $subNameNoQ = $subtitle.Name
            $subPathNoQ = Join-Path $currentDirectory $subNameNoQ
            $subFile = "`"$($subPathNoQ)`""

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
Start-Process -FilePath $mkvmergePath -ArgumentList $arguments -Wait -nonewwindow -passthru 

if (Test-Path -Path $outputPathNoQ -PathType Leaf)
        {
        Write-Host "Remuxed files: $($videoFile.Name), $($matchingSubtitles.Count) subtitles => $outputFile"

    } else {
        Write-Host "Ran into some issue with the arguments for this file - " 
        Write-Host $arguments
        write-host "------"
        $errorCount = $errorCount+1
    }
}

        #update the text file to remove finished line
        if ($errorCount=0) {
        $newContent = (Get-Content $batchPath) -replace [Regex]::Escape($currentDirectory),""
        $newContent | Set-Content -Path $batchPath
        }
}