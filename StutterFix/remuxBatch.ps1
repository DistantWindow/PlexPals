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

# read the global config file
$currPath = Get-Location
$parentPath = Split-Path -Path $currPath -Parent
$globalConfigFile = Join-Path $parentPath "PlexPal_GlobalConfig.ini"
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

    if ($matchingSubtitles) {
       $matchingSubtitles
        # Build the argument list for mkvmerge
       
         foreach ($subtitle in $matchingSubtitles) {
            $subNameNoQ = $subtitle.Name
            $subPathNoQ = Join-Path $currentDirectory $subNameNoQ
            $subFile = "`"$($subPathNoQ)`""
            $subBaseName = $subtitle.baseName

                #try to determine language
                $subLang = $subBaseName.split('.')[1]
                if ([string]::IsNullOrEmpty($subLang)) {
                $subLang = "und"
                }
            $currentSubtitle = "--language 0:$($subLang) $($subFile) "
            write-host $currentSubtitle

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