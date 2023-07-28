#=================================================#
#          SUPER-MEGA BATCH TRANSCODER            #
#=================================================#

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

#=================================================#
#                CONFIGURATION                    #
#=================================================#
# The below values are read from the config.ini. Review
# the comments within the config for more details on formatting 
# and what each does

Clear-Host # reset the console window, helps with debugging in Powershell ISE

# read the global config
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

$BaseDownloadPath = $config.BaseDownloadPath 

$otherVideoFormats = $config.validVideoFormats.Split(",") 

$DoneFolder = "done" #specify a subfolder name that will be created within each found folder to backup the old files after transcoding (ie done to use %BaseDownloadPath%\%foundFolder%\done)

$OutFolder = "out" #specify a subfolder name that will be created within each found folder to save the new transcoded file after transcoding and any found or processed SRTs

$SubsWorkFolder = "subs" #specify a working folder for .en.mp4 (containerized webvtt files) to be stored for processing

$vttworkFolder = "subs\vtt" #specify a sub-working folder for .vtt subtitles to be stored for processing to SRT

$x265CRF = $config.x265CRF 

$LogPath = Join-Path $BaseDownloadPath $config.LogPath 

#=================================================#
#                EXECUTION START                  #
#=================================================#

#get all the folders in the base directory
$folderList = get-childitem $BaseDownloadPath -Directory

#iterate each folder
foreach ($folder in $folderList) {
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

    #make sure working directories within each folder are created
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
            write-host "is a video? "$isAVideo

            write-host $item.fullname " " $fileNameExt

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

            #transcode mkv with contained streams to x265 MKV and move old file to /done
            elseif ($fileNameExt.Contains(".mkv")) {

                write-host $fileNameExt

                $currEpisodeIn = $fullFileName
                $mkvOutputName = $fileNameExt
                $currEpisodeDone = join-path $currDoneDir $fileNameExt
                $currEpisodeOut = join-path $currOutDir $fileNameExt
                write-host $currEpisodeDone
                write-host $currEpisodeOut
                
                #do ffmmpeg steps
                $ffmpegArgs = "-i `"$($currEpisodeIn)`" -map 0 -c:a copy -c:v libx265 -crf $($x265CRF) -vtag hvc1 `"$($currEpisodeOut)`""
                write-host $ffmpegArgs
                $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
                move-item -literalpath $currEpisodeIn -destination $currEpisodeDone
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
                
                #do ffmmpeg steps
                $ffmpegArgs = "-i `"$($currEpisodeIn)`" -c:v libx265 -crf $($x265CRF) -vtag hvc1 `"$($currEpisodeOut)`""
                write-host $ffmpegArgs
                $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
                move-item -literalpath $currEpisodeIn -destination $currEpisodeDone
                }

            #log other files that can't be handled
            else {
            write-host "$($fullFileName) is a file of unknown type and cannot be handled automatically. Leaving alone."
            }
        }
            
    write-host "///////"
}