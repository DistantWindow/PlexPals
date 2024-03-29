###########################################################
#             VIDEO THUMBNAIL GENERATIION                 #
###########################################################

##########################################################
#
# Use this Pal to generate random thumbnails/screenshots from
# all videos in a source directory. Specify the Config values
# in the ini, then right-click the script and Run in Powershell.
# The screenshots will be captured and output to the chosen 
# directory. If you aren't satisfied with any of them, simply 
# delete them and run the script again with some different
# timing values. The script will automatically skip any screenshots
# that already exist.
# The chosen input path is fully recursive, so any subfolders within
# the specified directory will also be scanned, and that same folder
# structure will be recreated in the specified output location.
#########################################################

#=================================================#
#                CONFIGURATION                    #
#=================================================#
# The below values are read from the config.ini. Review
# the comments within the config for more details on formatting 
# and what each does

Clear-Host # reset the console window, helps with debugging in Powershell ISE
$host.ui.RawUI.WindowTitle = �Auto-Gen Thumbnails - PlexPals�
# read the global config file
#region find global config
#Look for the Global Config in parent directories
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

# read the config file
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
 $ffmpegLocation = $gconfig.ffmpegLocation
# specify the location to find the video files
 $workPath = $config.workPath
# specify where the output should be stored
 $outputPath = $config.outputPath

# the timecode to pull the first screenshot from, in 00:00:0.00 format (HH:MM:SS.mm)
 $screenshotTimeCode = [timespan]$config.screenshotTimeCode 
# if multiple screenshots should be taken, enter the value here. to take just one, enter 1.
 $numberOfScreens = $config.numberOfScreens
# if doing multiple screenshots, the delay to add between each, in 00:00:00.00 format (HH:MM:SS.mm)
 $screenshotDelay = [timespan]$config.screenshotDelay 

###########################################################
#                      EXECUTION                          #
###########################################################

 # get the top-level subfolder of the work path, to be used in constructing the output path
 $parentSubfolder  = $workPath.Split("\",55)[-1]
 
 # get all items recursively in the specified path
 $currItems = Get-ChildItem -Path $workPath -Recurse -File 
 # store the original screenshot starting time as a separate value
 $baseScreenshotTime = $screenshotTimeCode

 foreach ($currFile in $currItems){
  # set the screenshot time back to it's original value
  $screenshotTimeCode = $baseScreenshotTime
  # get the full name and base name of the current file
  $currFullPath = $currFile.FullName
  $currBaseName = $currFile.BaseName
  
  # if the current file isn't an MP4 or MKV video, skip it and move on
  if (!($currFullPath.contains(".mp4") -or $currFullPath.contains(".mkv"))){Continue}

  # get the current subfolder's name, to be used in constructing the output path
  $childSubfolder = $currFullPath.Split("\",55)[-2]

  # combine the specified output path, parent subfolder, and child subfolder into the output path for this file
  $outputFullPath=[IO.Path]::Combine($outputPath,$parentSubfolder,$childSubfolder)
        
        # create that path if it doesn't exist
        If(!(test-path -PathType container $outputFullPath))
        {
        New-Item -ItemType Directory -Path $outputFullPath
        }
  
  # reset the loopcount
  $loopCount = 0

  # keep taking screenshots until the number specified has been satisfied
  while ($loopCount -le $numberOfScreens) {

  $loopCount++

    # prevent an infinite loop by exiting if the loop count exceeds the screenshot count somehow
    if ($loopCount -gt $numberOfScreens){Continue}

  # make the current thumbnail name using the filename, loopcount, and extension
  $currThumbnailName = "$($currFile.BaseName) $($loopCount).jpg"
  # build the final output path
  $outputFinalPath = Join-Path $outputFullPath $currThumbnailName

        #if the specified jpg already exists, continue to the next loop
        If((test-path -PathType leaf $outputFinalPath))
        {
        write-host "File $($outputFinalPath) already exists. Skipping."
        Continue
        }
  
  # build arguments for ffmmpeg using the current timespan, input path, and output path
  $argumentList = "-ss $($screenshotTimeCode) -i `"$($currFullPath)`" -vframes 1 `"$($outputFinalPath)`" -y"
  Write-Host $argumentList
  # run ffmpeg with the specified arguments
  Start-Process -FilePath $ffmpegLocation -ArgumentList $argumentList -Wait -NoNewWindow -PassThru

  #add the specified delay to the screenshot timecode for the next loop
  $screenshotTimeCode = $screenshotTimeCode+$screenshotDelay
  }
 }