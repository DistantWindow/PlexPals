#=================================================#
#           BATCH REMUXER/STUTTERFIX              #
#=================================================#

##############################################
# This Pal will read a list of file paths from a specified text file, and then go through each of those
# and remux the contained mp4/srt pairs into MKV files. This will work either for single videos or for seasons
# with multiple videos and subtitles per folder.
#
# Start by creating a new text file containing a list of the folders that contain files to Remux.
# Indicate the path to this file in the config.ini file.
# Right-click the script and Run with Powershell, and it will process all listed items.
#
# After completion, you can delete the original mp4/SRT files. The script doesn't do this automatically in case of any issue.
##############################################

#=================================================#
#                CONFIGURATION                    #
#=================================================#
# The below values are read from the config.ini. Review
# the comments within the config for more details on formatting 
# and what each does

Clear-Host # reset the console window, helps with debugging in Powershell ISE
$host.ui.RawUI.WindowTitle = “StutterFix Batch (MKV) - PlexPals”
# read the global config file
#region Look for the Global Config in parent directories
write-host "Looking for Global Config file..."
$targetFile = "PlexPal_GlobalConfig.ini"
$nextParent  = Get-Location
$globalConfigFile = join-path $nextParent $targetFile
$configFound = Test-Path -Path $globalConfigFile

#if not found at the current location, go up levels until it is found
while (-not ($configFound -eq $true)) {
    try {
    $nextParent = split-path $nextParent -Parent
    $globalConfigFile = join-path $nextParent $targetFile
    write-host "Config not found at $($globalConfigFile)"
    
    $configFound = Test-Path -Path $globalConfigFile
    write-host "Checking in $($nextParent) next..."
      if (([string]::IsNullOrEmpty($nextParent)) -or ([string]::IsNullOrWhitespace($nextParent))) {
        throw "PlexPals Global Config could not be found"
        }
    } catch {
        throw "PlexPals Global Config could not be found"   
        }
}
write-host "Global config found at $($globalConfigFile)"
#endregion
Get-Content $globalConfigFile | foreach-object -begin {$gConfig=@{}} -process {
    $line = $_.Trim()
    if(-not $line.StartsWith("#") -and $line -notmatch '^\s*$' -and $line -notmatch '^\[') {
        $k, $v = $line -split '=', 2
        if(($k.Trim().CompareTo("") -ne 0) -and ($k.Trim().StartsWith("[") -ne $True)) {
            $gConfig.Add($k.Trim(), $v.Trim())
        }
    }
}

# read the script config file
$configFile = "config.ini"
Get-Content $configFile | foreach-object -begin {$config=@{}} -process {
    $line = $_.Trim()
    if(-not $line.StartsWith("#") -and $line -notmatch '^\s*$' -and $line -notmatch '^\[') {
        $k, $v = $line -split '=', 2
        if(($k.Trim().CompareTo("") -ne 0) -and ($k.Trim().StartsWith("[") -ne $True)) {
            $config.Add($k.Trim(), $v.Trim())
        }
    }
}

# assign config values to script variables
$mkvmergePath = $gConfig.mkvmergePath
$batchPath = $config.batchPath

#=================================================#
#                EXECUTION START                  #
#=================================================#
# Get the current working directory
(get-content $batchPath)| ForEach-Object {
$errorCount= 0
$currentDirectory = $_
write-host $currentDirectory

# Get all the mp4 and srt files in the current directory
$videoFiles = Get-ChildItem -Path $currentDirectory -Filter "*.webm"
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
       $matchingSubtitles
        # Build the argument list for mkvmerge
       
         foreach ($subtitle in $matchingSubtitles) {
            $typeFlag = $null
            $trackName = $null
            $subNameNoQ = $subtitle.Name
            $subPathNoQ = Join-Path $currentDirectory $subNameNoQ
            $subFile = "`"$($subPathNoQ)`""
            $subBaseName = $subtitle.baseName


                #try to determine language
                $subLang = $subBaseName.split('.')[-1]
                write-host $subFile
                write-host $subBaseName
                write-host $subLang
                write-host "------"
                
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