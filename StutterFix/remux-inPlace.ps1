clear-host
$host.ui.RawUI.WindowTitle = “StutterFix (In-Place) - PlexPals”
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
    $subCount=1

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
       $matchingSubtitles
        # Build the argument list for mkvmerge
       
         foreach ($subtitle in $matchingSubtitles) {
           $typeFlag = $null
            $trackName = $null
            $subFile = "`"$($subtitle.Name)`""
            $subBaseName = $subtitle.baseName

                #try to determine language
                $subLang = $subBaseName.split('.')[-1]
                
                # if the last element is a type tag such as SDH instead of a language, handle that
                if (($subLang -eq "sdh") -or ($subLang -eq "forced") -or ($subLang -eq "cc")) {
                        $subType = $subLang

                        # set type flag for SDH/CC subtitles and Forced subtitles separately
                         if (($subType -eq "sdh") -or ($subType -eq "cc")){
                          $typeFlag = " --hearing-impaired-flag 0:yes "
                          $trackName = " --track-name 0:SDH "
                         } elseif ($subType -eq "forced"){
                          $typeFlag = " --forced-display-flag 0:yes "
                          $trackName = " --track-name 0:Forced "
                         }
                        
                        #find the language on sdh/forced subtitles, moving through the array til a tag other than sdh/forced/cc is found
                        $endOfArray=-1
                            while (($subLang -eq "sdh") -or ($subLang -eq "forced") -or ($subLang -eq "cc")) {
                            $endOfArray--
                            write-host $endOfArray
                            $subLang = $subBaseName.Split(".")[$endOfArray]
                            write-host $subLang
                                                        }
                            }
                            
                            if ($subLang.length -gt 3) {
                            throw "Did not find a valid language tag in subtitle file: $($subFile). Please review Plex documentation and ensure a 2- or 3-character language tag conforming to ISO 639-1 is provided."
                            }
            #build the command for the current subtitle
            $currentSubtitle = "--language 0:$($subLang) $($typeFlag)$($trackName)$($subFile) "
            write-host $currentSubtitle

            #add the current subtitle to the argument string
            $arguments += $currentSubtitle
            write-host $arguments
            write-host "===="
        }} 
          else 
            {
            write-host "No subtitles found"
          }

# Execute the mkvmerge command to remux the files
$mergeCommand = "$($mkvmergePath) $($arguments)"
Write-Host $mergeCommand
Start-Process -FilePath $mkvmergePath -ArgumentList $arguments -Wait -nonewwindow -passthru 

if (Test-Path -Path $outputFileNoQ -PathType Leaf)
        {
        Write-Host "Remuxed files: $($videoFile.Name), $($matchingSubtitles.Count) subtitles => $outputFile"
    } else {
        Write-Host "Ran into some issue with the arguments for this file - " 
        Write-Host $arguments
    }
}

