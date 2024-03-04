#=================================================#
#              MATCHUP SUBTITLES                  #
#=================================================#
#region introduction
##############################################
#
# If you have a folder containing video files and subtitles which do not have exactly matching names,
# use this script to bring them into alignment.
# The subtitles will need to have the correct season and episode number at the beginning, which 
# can be easily accomplished using a tool like Bulk Rename Utility. There should be a delimiter after
# the season/episode number, which should be set in the config.
#
# The script will iterate through all files in the specified folder. For each video of the chosen type,
# a subtitle with the same epiosde number will be found. That subtitle will be renamed to match the video
# with the matching number.
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
$host.ui.RawUI.WindowTitle = “Matchup Subtitle Names - PlexPals”
# locate and read the global config
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

$workPath = $config.workingPath
$videoFormat = $config.videoFormat
$epNoDelimiter = $config.epNoDelimiter
#endregion


#=================================================#
#                  EXECUTION                      #
#=================================================#

$videoFiles = Get-ChildItem -Path $workPath -Filter "$($videoFormat)"
$subtitles = Get-ChildItem -Path $workPath -Filter "*.srt"

foreach ($file in $videoFiles) {

$fileExtName = $file.name
$fileBaseName = $file.BaseName
$episodeNumber,$episodeTitle = $fileBaseName.split("-",2)

$matchingSubtitles = $subtitles | Where-Object { $_.BaseName -like "*$episodeNumber*" }
write-host "curr ep: "$episodeTitle
if ($matchingSubtitles) {
 foreach ($subtitle in $matchingSubtitles)
 {
 write-host $subtitle.FullName
 #check for language/type tags
     $originalSubBase = $subtitle.baseName
     if ($originalSubBase -like "*.*") {
    
      $finalElement = $originalSubBase.split(".")[-1]
        if (($finalElement -eq "sdh") -or ($finalElement -eq "forced") -or ($finalElement -eq "cc")) {
            $subType = $finalElement
            $langTag = $originalSubBase.split(".")[-2]
            $subBaseName = "$($fileBaseName).$($langTag).$($subType)"
            } elseif ($finalElement.length -le 3) {
                $langTag = $finalElement
                $subBaseName = "$($fileBaseName).$($langTag)"
                } else {
                     $subBaseName = $fileBaseName
                     write-host "language could not be identified, please add it manually"
                     }
    } else {
        $subBaseName = $fileBaseName
        write-host "language could not be identified, please add it manually"
    }
 #assign new subtitle name
 $newSubName = "$($subBaseName).srt"
 write-host $newSubName
 Rename-Item -Path $subtitle.FullName -NewName $newSubName
 }
}

}