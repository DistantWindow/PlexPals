#=================================================#
#            BATCH YT-DLP DOWNLOADER              #
#=================================================#

######################################################################
# This guy enables downloading of multiple batches of files via      #
# YT-DLP using the -a batch download option.                         #
#                                                                    #
# Point the configuration values below to a desired                  #
# download directory; this is where downloaded files will be         #
# output.                                                            #
#                                                                    #
# Save .txt files containing lists of videos to download             #
# in the path indicated by $InputBase. Once all videos from that     #
# file are complete, the file will move to $InputDone and can        #
# be deleted (or restored if any issues occurred.)                   #
#                                                                    #
# The downloaded files will be saved in subfolders with the name     #
# of the text file. If the textfile contains a season indicator      #
# at the end (formatted like 'S03'), that can be used to name each   #
# downloaded file if "$PrefixSeasonNo" is true                       #
#                                                                    #
# There's not a very reliable way to get an episode number, at least #
# not that I know of, so... for right now it's just doing "EXX" so   #
# it's easier to manually update with a find-and-replace later.      #
# Mileage may vary site-to-site on that one, I suppose.              #
######################################################################

#=================================================#
#                CONFIGURATION                    #
#=================================================#
# The below values are read from the config.ini. Review
# the comments within the config for more details on formatting 
# and what each does

Clear-Host # reset the console window, helps with debugging in Powershell ISE

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
$DownloadBase = $config.DownloadBase

$InputBase = $config.InputBase
$InputDone = Join-Path $InputBase "done"

$ytDlpPath = $config.ytDlpPath

$PrefixSeasonNo = $config.PrefixSeasonNo

$formatArgs = $config.formatArgs
$cookieArgs = $config.cookieArgs
$subtitleArgs = $config.subtitleArgs
$namingFormat = $config.namingFormat

#=================================================#
#                  EXECUTION START                #
#=================================================#

# create input/done if it doesn't exist
If(!(test-path -PathType container $InputDone)) 
   {New-Item -ItemType Directory -Path $InputDone}

# get all the input file lists from input
$batchLists = Get-ChildItem $InputBase -Attributes !Directory

# iterate each and download them to a separate folder
foreach ($txtfile in $batchLists) {
write-host $txtfile
write-host $txtfile.FullName

#reset some stuff for some reason? weird bugs otherwise
$showName=$null
$episodeDLPath = $null
$outputArgs = $null
$listPath = $null
$listSource = $null
$ytDlpArgs = $null


# get the show/season name from the text file

$playlistFile = $txtfile.FullName
write-host $playlistFile
$showName = $txtfile.basename
    #try to get the season name from the show name
    if($showName.Length -gt 3){
    $seasonNumber = $showName.Substring($showName.Length - 3) 
    write-host $seasonNumber
    $seasonPattern = '^S\d{2}$'
       if ($seasonNumber -notmatch $seasonPattern) {
       $seasonNumber = $null
       }
    } else {
        $seasonNumber = $null
        }

 
# set the path to download to based on the show/season
$seasonDLPath = Join-Path $DownloadBase $showName
Write-host $seasonDLPath
write-host $playlistFile

# build the episode-specific arguments


   # if prefix is true, and season number is provided, use it
   if ($PrefixSeasonNo -eq $true -and -not($seasonNumber -eq $null)) {
      $episodeName = "$($seasonNumber)EXX $($namingFormat)"
         } else {
             $episodeName = $namingFormat
         }
        

$episodeDLPath = "`"$($seasonDLPath)\$($episodeName)`"" # build output path for the current video
$outputArgs = "-o",$episodeDLPath # download each episode in a text file to a specific folder
$listPath = "`"$($playlistFile)`"" 
write-host $listPath
$listSource = "-a",$listPath # get video URLs to download from the current iterated text file


$ytDlpArgs = [string]::Concat($formatArgs,' ',$cookieArgs,' ',$subtitleArgs,' ',$outputArgs,' ',$listSource)
write-host "args:",$ytDlpArgs
write-host "===="

# run YT-DLP with the constructed arguments
try{
$runYTDlp = Start-Process -FilePath $ytDlpPath -argumentlist $ytDlpArgs -nonewwindow -wait -passthru
write-host "Finished downloading all episodes from",$showName
Move-Item -path $playlistFile -destination $InputDone
}
catch {
write-host "oops",$Error
}
finally {
write-host "//////"
}

}
write-host "All files from "$InputBase" processed successfully."
