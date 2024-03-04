#=================================================#
#          SUPER-MEGA BATCH TRANSCODER            #
#=================================================#
#region introduction
##############################################
# This script will handle batch transcoding of video files into the handy, space-saving X265 format using FFMPEG.
# It expects a particular structure - point the script to a starting $BaseDownloadPath in the config file,
# and from there it will look for subfolders within that folder. Each folder should contain at least one video file.
#
# For instance if your base folder is ToTranscode\, put OversizedMovie.mp4 into a subfolder "OverSizedMovie" of that
# directory, or put Season 2 of Oversized TV Show into a folder OversizedTVS02. The script will scan each subfolder, 
# find files it can handle, process things into the correct format, and put the finished files in an "out" subfolder 
# and move the old files into a "done" subfolder that can be deleted after validating the output looks how you want.
#
# The files will be transcoded using the CRF specifed in the config. MKVs will be converted to MKV with all their original
# streams (subtitles, audio, etc) included, and any other specified video formats will be converted to MP4.
# For subtitles downloaded from some sources, they may come in a weird .en.mp4 container which will be converted to SRT.
#
# To-do - add some logging to capture the starting size/duration, ending size/duration, transcode time, and other details
#         to a CSV
#
##############################################
#endregion
#=================================================#
#                CONFIGURATION                    #
#=================================================#
#region Config Values
# The below values are read from the config.ini. Review
# the comments within the config for more details on formatting 
# and what each does

Clear-Host # reset the console window, helps with debugging in Powershell ISE
$host.ui.RawUI.WindowTitle = “Batch Transcoder - PlexPals”
# read the global config
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

# read the local config file
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
$MP4BoxPath = $gconfig.MP4BoxPath

$FFMpegPath = $gconfig.ffmpegLocation

$FFProbePath = $gconfig.ffprobePath

$BaseDownloadPath = $config.BaseDownloadPath 

$otherVideoFormats = $config.validVideoFormats.Split(",")

$DoneFolder = "done" #specify a subfolder name that will be created within each found folder to backup the old files after transcoding (ie done to use %BaseDownloadPath%\%foundFolder%\done)

$OutFolder = "out" #specify a subfolder name that will be created within each found folder to save the new transcoded file after transcoding and any found or processed SRTs

$SubsWorkFolder = "subs" #specify a working folder for .en.mp4 (containerized webvtt files) to be stored for processing

$vttworkFolder = "subs\vtt" #specify a sub-working folder for .vtt subtitles to be stored for processing to SRT

$transcodeMethod = $config.qualityMethod
if ($transcodeMethod -eq $null){$transcodeMethod="CRF"}

$speedProfile = $config.speedProfile
if ($speedProfile -eq $null){$speedProfile="medium"}

$x265CRF = $config.x265CRF 
$videoBitrate = $config.targetBitrateV
$audioBitrate = $config.targetBitrateA

$cleanupSetting = $config.cleanupSetting
if (($cleanupSetting -eq $null) -or ($cleanupSetting -gt 3)){$cleanupSetting=1}

$LogPath = $config.LogPath 
write-host $LogPath
#add visual basic so we can send fiels to recylce bin
Add-Type -AssemblyName Microsoft.VisualBasic
#endregion
#=================================================#
#                HANDY FUNCTIONS                  #
#=================================================#
#region declare functions
function Compare-VideoDurations {
    param (
        [string]$ffprobePath,
        [string]$inputPath,
        [string]$outputPath
    )
    # usage example | $durationMatch, $inputDuration, $outputDuration = Compare-VideoDurations -inputPath $inputFile -outputPath $outputFile

    #default ffprobe if not provided
    write-host "probe $($ffprobePath)"
    if ([string]::IsNullOrEmpty($ffprobePath)){$ffprobePath="ffprobe.exe"}

    # Check if ffprobe is available
    #if (-not (Test-Path $ffprobePath)) {
     #   Write-Host "Error: ffprobe is not found. Please make sure it's installed and in the system PATH." -ForegroundColor Red
      #  return
    #}

    # Get duration of input video
    $inputDuration = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath

    # Get duration of output video
    $outputDuration = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $outputPath

    # Compare durations
    if ($inputDuration -eq $outputDuration) {
        Write-Host "The durations are equal: $($inputDuration) seconds." -ForegroundColor Green
        $duarionMatch = $true
    } else {
        Write-Host "The durations are not equal." -ForegroundColor Red
        Write-Host "Input video duration: $($inputDuration) seconds" -ForegroundColor Yellow
        Write-Host "Output video duration: $($outputDuration) seconds" -ForegroundColor Yellow
        $durationMatch = $false
    }
    return $durationMatch, $inputDuration, $outputDuration
}

function compare-FileSize {
    param (
        [string]$inputPath,
        [string]$outputPath
    )
    # usage example | $inputKB, $outputKB, $diffPercent = compare-FileSize -inputPath $inputFile -outputPath $outputFile
    $inputSize = (Get-ChildItem -LiteralPath $inputPath).Length
    $inputKB = $([math]::Round($inputSize/1KB,2))
    $outputSize= (Get-ChildItem -LiteralPath $outputPath).Length
    $outputKB = $([math]::Round($outputSize/1KB,2))
    $differenceKB = [math]::Round($outputKB-$inputKB,2)
    $differencePercent = [math]::Round(($outputSize/$inputSize)*100,2)
    write-host $testVar "hi"
    return $inputKB, $outputKB, $differencePercent
}

function move-finishedFile {
  param (
        [string]$cleanupOption,
        [string]$startingFile,
        [string]$finishedFile
    )
#example usage | $moveResult, $finalPlace = move-finishedFile -cleanupOption 2 -startingFile $inputFile -finishedFile $outputFile
#add visual basic so we can send files to recylce bin
Add-Type -AssemblyName Microsoft.VisualBasic
    $moveResult = $null
        
    if ([string]::IsNullOrEmpty($doneFolder)){$doneFolder="done"}

    #get the done path 
    $workingFolder=split-path -path $startingFile
    $funcDonePath = join-path $workingFolder $DoneFolder
    
    #override cleanup setting if 2 and no comparison was provided
    if (($cleanupOption -eq 2) -and ([string]::IsNullOrEmpty($finishedFile))){$cleanupOption=3}
    
    #cleanup the input file
    if ($cleanupOption -eq 1) {
    #move file to Output Path
    move-item -literalpath $startingFile -destination $funcDonePath
    $moveResult = "Moved $($startingFile.name) to $funcDonePath"
    $finalRestingPlace="Done"
    } elseif ($cleanupOption -eq 2) {
    #move file to recycle bin if output is smaller
    write-host "Comparing file size..."
    $inputKB, $outputKB, $diffPercent = compare-FileSize -inputPath $startingFile -outputPath $finishedFile
    write-host $diffPercent
        if ($diffPercent -le 100) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($startingFile,'OnlyErrorDialogs','SendToRecycleBin')
        $moveResult = "Output file is smaller than original, sent original to Recycle Bin"
        $finalRestingPlace="Recycle Bin"
        } else {
        #move file to Output Path
            
            move-item -literalpath $startingFile -destination $funcDonePath
            $moveResult = "Output file is larger than original. Moved original to $($funcDonePath)"
            $finalRestingPlace="Done"
            }
    } elseif ($cleanupOption -eq 3) {
    #move file to recylce bin
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($startingFile,'OnlyErrorDialogs','SendToRecycleBin')
    $moveResult = "Moved $($startingFile.name) to Recycle Bin"
    $finalRestingPlace="Recycle Bin"
    } else {
    $moveResult="Couldn't do anything with $($startingFile)"
    $finalRestingPlace="Unmoved"
    write-host "`'$($cleanupOption)`'"
    }
    $finalCleanupSetting = $cleanupOption
    write-host $moveResult
    return $moveResult, $finalRestingPlace
}

function write-TranscodeLog {
  param (
        [string]$logPath,
        [string]$startingFile,
        [string]$finishedFile,
        [string]$ffprobePath,
        [string]$startTime,
        [string]$endTime,
        [string]$originalSentTo
        )
 write-host "probe $($ffprobepath)"
#default ffprobe if not provided
if ([string]::IsNullOrEmpty($ffprobePath)){$ffprobePath="ffprobe.exe"}
write-host $logpath
$pathThere = test-path -path $logPath -PathType Leaf
write-host $pathThere
#create the log if it doesn't exist
if (-not (test-path -path $logPath -PathType Leaf)) {
 $newLogHeader = "fileName,startTime,finishTime,inputDuration,inputSizeKB,outputDuration,outputSizeKB,sizeDifference,inputMovedTo"
 write-host $newLogHeader
 New-Item -ItemType File -Path $logPath
 out-file $logPath -InputObject $newLogHeader -Encoding UTF8
}

#isolate the file name 
    $fileName = Split-Path -Leaf $startingFile

#if provided, only write inputMovedTo
if (-not([string]::IsNullOrEmpty(($originalSentTo)))) {
    write-host "moved"
    $inputMovedTo = "$($originalSentTo) - $($finishedFile)"
    } else {
    
    #get the durations
    $durationMatch, $inputDuration, $outputDuration = Compare-VideoDurations -inputPath $startingFile -outputPath $finishedFile -ffprobePath $ffprobePath
    #get the sizes
    $inputKB, $outputKB, $diffPercent = compare-FileSize -inputPath $startingFile -outputPath $finishedFile

    #build the new log row
    $inputDurationSec = "$([math]::round($inputDuration,2)) sec"
    $outputDurationSec = "$([math]::round($outputDuration,2)) sec"
    $inputSizeKB = "$($inputKB) KB"
    $outputSizeKB = "$($outputKB) KB"
    $sizeDifference = "$($diffPercent)%"
    }

$newLogRow = "$($fileName),$($startTime),$($endTime),$($inputDurationSec),$($inputSizeKB),$($outputDurationSec),$($outputSizeKB),$($sizeDifference),$($inputMovedTo)"
 out-file $logPath -InputObject $newLogRow -Encoding UTF8 -Append
}

#endregion
#=================================================#
#                EXECUTION START                  #
#=================================================#
#region starting declarations
#get all the folders in the base directory
$folderList = get-childitem $BaseDownloadPath -Directory

#build the ffmpeg base argument with the specified settings
if ($transcodeMethod -eq "CRF") {
$baseQualityArg = "-preset $($speedProfile) -c:v libx265 -crf $($x265CRF) -vtag hvc1"
} elseif ($transcodeMethod -eq "ABR") {
$baseQualityArgP1 = "-preset $($speedProfile) -c:v libx265 -b:v $($targetBitrate) -x265-params pass=1 -an -f null NUL"
$baseQualityArgP2 = "-preset $($speedProfile) -c:v libx265 -b:v $($targetBitrate) -x265-params pass=2 -c:a aac -b:a $($targetBitrateAudio)"
} else { throw "Invalid argument $($transcodeMethod) provided for qualityMethod"
}
#endregion

#iterate each folder
foreach ($folder in $folderList) {
    #region log and reset
    write-host "======="
    write-host $folder.FullName
    write-host "======="
    
    #reset some values to null to prevent weird looping path bugs
    $subfolderContents = $null
    $mp4SubWorkDir = $null
    $vttSubWorkDir = $null
    $currDoneDir = $null
    $currOutDir = $null
    

    #set folder-specific paths for working directories
    $fullFolderPath = $folder.FullName
    $mp4SubWorkDir = join-path $fullFolderPath $SubsWorkFolder
    $vttSubWorkDir = join-path $fullFolderPath $vttworkFolder
    $currDoneDir = join-path $fullFolderPath $DoneFolder
    $currOutDir = join-path $fullFolderPath $OutFolder
    $currDoneSubsDir = [IO.Path]::Combine($fullFolderPath,$DoneFolder,$SubsWorkFolder)
    #endregion

    #make sure working directories within each folder are created
    #region pathtests
    If(!(test-path -PathType container $mp4SubWorkDir)) #make sure \subs folder exists
        {
        New-Item -ItemType Directory -Path $mp4SubWorkDir
        }

    If(!(test-path -PathType container $vttSubWorkDir)) #make sure \subs\vtt folder exists
        {
        New-Item -ItemType Directory -Path $vttSubWorkDir
        }

    If(!(test-path -PathType container $currDoneDir)) #make sure \done folder exists
        {
        New-Item -ItemType Directory -Path $currDoneDir
        }

    If(!(test-path -PathType container $currOutDir)) #make sure \out folder exists
        {
        New-Item -ItemType Directory -Path $currOutDir
        }

    If(!(test-path -PathType container $currDoneSubsDir)) #make sure \done\subs folder exists
        {
        New-Item -ItemType Directory -Path $currDoneSubsDir
        }
        #endregion

    #get folder contents
    $subfolderContents = Get-ChildItem $fullFolderPath -Attributes !Directory

        #iterate each file in the folder and handle them as needed
        foreach ($item in $subfolderContents) {
            write-host "--------"
            
            $fullFileName = $item.FullName
            $fileNameExt = $item.Name
            $baseFileName = $item.BaseName

            #see if current file is one of the defined video formats
            $isAVideo = ($otherVideoFormats | %{$fileNameExt.contains($_)}) -contains $true
            write-host "is a video? $($isAVideo)"

            write-host "$($item.fullname) $($fileNameExt)"

            #region handle subtitles
            #see if the file is an en.mp4-formatted subtitle, and if so convert to SRT
            if ($fileNameExt.Contains(".en.mp4")) {
                write-host "Found subtitle "$fileNameExt
                $currMP4Work = join-path $mp4SubWorkDir $fileNameExt
                $currMP4Done = Join-Path $currDoneSubsDir $fileNameExt
                write-host $currmp4work
                write-host $currMP4Done

                #move the mp4 sub to the mp4 working directory
                move-item -literalpath $fullFileName -destination $currMP4Work
                
                #convert the mp4 sub to vtt with mp4box

                    $vttFileName = "$($baseFileName).vtt"
                    $currVTTWork = join-path $vttSubWorkDir $vttFileName
                    $currVTTDone = join-path $currDoneSubsDir $vttFileName
                    write-host $currVTTWork
                    write-host $currVTTDone

                    #mp4box steps
                    $mp4BoxArgs = "-raw 1 `"$($currMP4Work)`" -out `"$($currVTTWork)`""
                    write-host $mp4BoxArgs
	               $mp4BoxProcess = Start-Process -FilePath $MP4BoxPath -ArgumentList $mp4BoxArgs -nonewwindow -wait
                    #move mp4sub to done/subs
                   move-item -literalpath $currMP4Work -destination $currMP4Done

                #convert the vtt sub to srt with ffmpeg
                    $srtFileName = "$($baseFileName).srt"
                    $srtDonePath = join-path $currOutDir $srtFileName
                    write-host $srtDonePath

                    #ffmpeg steps
                   	$ffmpegArgs = "-i `"$($currVTTWork)`" `"$($srtDonePath)`""	
                    write-host $ffmpegArgs
	               $ffmpegProcess = Start-Process -FilePath $FFMpegPath -ArgumentList $ffmpegArgs -NoNewWindow -wait

                    #move vtt sub to done/subs
                  move-item -literalpath $currVTTWork -destination $currVTTDone
                }

            #convert vtt to SRT
            elseif ($fileNameExt.Contains(".vtt")) {
                    $vttFileName = "$($baseFileName).vtt"
                    $currVTTWork = $fullFileName
                    $currVTTDone = join-path $currDoneSubsDir $vttFileName
                    write-host $currVTTWork
                    write-host $currVTTDone

                #convert the vtt sub to srt with ffmpeg
                    $srtFileName = "$($baseFileName).srt"
                    $srtDonePath = join-path $currOutDir $srtFileName
                    write-host $srtDonePath

                #ffmpeg steps
                   	$ffmpegArgs = "-i `"$($currVTTWork)`" `"$($srtDonePath)`""	
                    write-host $ffmpegArgs
	               $ffmpegProcess = Start-Process -FilePath $FFMpegPath -ArgumentList $ffmpegArgs -NoNewWindow -wait

                #move vtt sub to done/subs
                  move-item -literalpath $currVTTWork -destination $currVTTDone
            }

            #move existing SRTs to /out
            elseif ($fileNameExt.Contains(".srt")) {
            $srtDonePath = join-path $currOutDir $fileNameExt
            move-item -LiteralPath $fullFileName -Destination $srtDonePath
            }
            #endregion

            #region handle videos
            #transcode mkv with contained streams to x265 MKV and move old file to /done
            elseif ($fileNameExt.Contains(".mkv")) {

                write-host $fileNameExt

                $currEpisodeIn = $fullFileName
                $mkvOutputName = $fileNameExt
                $currEpisodeDone = join-path $currDoneDir $fileNameExt
                $currEpisodeOut = join-path $currOutDir $fileNameExt
                write-host $currEpisodeDone
                write-host $currEpisodeOut
                
                $startTimeStr = Get-Date -Format "yyyy/MM/dd HH:mm"
                #do ffmmpeg steps
                if ($transcodeMethod -eq "CRF") {

                $ffmpegArgs = "-i `"$($currEpisodeIn)`" -map 0 -c:a copy -c:s copy $($baseQualityArg) `"$($currEpisodeOut)`""
                write-host $ffmpegArgs
                $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
                
                } elseif ($transcodeMethod -eq "ABR") {

                $ffmpegArgsP1 = "-y -i `"$($currEpisodeIn)`" -map 0 -c:a copy -c:s copy $($baseQualityArgP1)"
                $ffmpegArgsP2 = "-i `"$($currEpisodeIn)`" -map 0 -c:a copy -c:s copy $($baseQualityArgP2) `"$($currEpisodeOut)`""
                write-host $ffmpegArgsP1
                $ffmpegProcess1 = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgsP1 -NoNewWindow -Wait -PassThru
                $ffmpegProcess2 = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgsP2 -NoNewWindow -Wait -PassThru
               
                }
                
                $endTimeStr = Get-Date -Format "yyyy/MM/dd HH:mm"
                write-TranscodeLog -logPath $logPath -startingFile $currEpisodeIn -finishedFile $currEpisodeOut -ffprobePath $ffprobepath -startTime $startTimeStr -endTime $endTimeStr

                $moveResult, $finalPlace = move-finishedFile -cleanupOption $cleanupSetting -startingFile $currEpisodeIn -finishedFile $currEpisodeOut
                write-TranscodeLog -logPath $logPath -startingFile $currEpisodeIn -finishedFile $currEpisodeOut -originalSentTo $moveResult 
             }
            
            #transcode other video files to x265 and move old file to /done
            elseif ($isAVideo -eq $true -and -not($fileNameExt.Contains(".en"))) {
                
                write-host $fileNameExt
                $currEpisodeIn = $fullFileName
                $mp4OutputName = "$($baseFileName).mp4"
                $currEpisodeDone = join-path $currDoneDir $fileNameExt
                $currEpisodeOut = join-path $currOutDir $mp4OutputName
                write-host $currEpisodeDone
                write-host $currEpisodeOut
                
                $startTimeStr = Get-Date -Format "yyyy/MM/dd HH:mm"
                #do ffmmpeg steps
                if ($transcodeMethod -eq "CRF") {

                $ffmpegArgs = "-i `"$($currEpisodeIn)`" $($baseQualityArg) `"$($currEpisodeOut)`""
                write-host $ffmpegArgs
                $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
                
                } elseif ($transcodeMethod -eq "ABR") {
                
                $ffmpegArgsP1 = "-y -i `"$($currEpisodeIn)`" $($baseQualityArgP1)"
                $ffmpegArgsP2 = "-i `"$($currEpisodeIn)`" $($baseQualityArgP2) `"$($currEpisodeOut)`""
                
                $ffmpegProcess1 = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgsP1 -NoNewWindow -Wait -PassThru
                $ffmpegProcess2 = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgsP2 -NoNewWindow -Wait -PassThru

                }
                
                $endTimeStr = Get-Date -Format "yyyy/MM/dd HH:mm"
                write-TranscodeLog -logPath $logPath -startingFile $currEpisodeIn -finishedFile $currEpisodeOut -ffprobePath $ffprobepath -startTime $startTimeStr -endTime $endTimeStr

                $moveResult, $finalPlace = move-finishedFile -cleanupOption $cleanupSetting -startingFile $currEpisodeIn -finishedFile $currEpisodeOut
                write-TranscodeLog -logPath $logPath -startingFile $currEpisodeIn -finishedFile $currEpisodeOut -originalSentTo $moveResult 
              }
            #endregion

            #log other files that can't be handled
            else {
            write-host "$($fullFileName) is a file of unknown type and cannot be handled automatically. Leaving alone."
            }
        }
            
    write-host "///////"
}
#Read-Host -Prompt "Press Enter to exit"