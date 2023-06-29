#provide the base location to download to
$DownloadBase = "E:\YTDLP\Download"
#provide the location where txt files listing urls to download are saved
$InputBase = "F:\Downloads\YTDLP\Seasons"
$InputDone = Join-Path $InputBase "done"
#provide the path to yt-dlp.exe
$ytDlpPath = "F:\Downloads\YTDLP\yt-dlp.exe"

#set global YTDLP argument values
{
$formatArgs = "--format `"bv*[height<=1080]+ba/b`"" # video formats to download. default finds best version up to 1080p.
$cookieArgs = "--cookies-from-browser Firefox" # where to retrieve cookies for sites that need them. Firefox recommended, Chrome cookie store is encrypted since latest update
$subtitleArgs = "--write-sub --write-auto-sub --sub-lang `"en.*`" --embed-subs" # if subtitles should be downloaded. default is to download the English subtitle.
$namingFormat = "%(title)s.%(ext)s" # how to name the 
}

#create input/done if it doesn't exist
If(!(test-path -PathType container $InputDone)) 
   {New-Item -ItemType Directory -Path $InputDone}

#get all the season lists from input
$seasonLists = Get-ChildItem $InputBase -Attributes !Directory

#iterate each and download them to a separate folder
foreach ($txtfile in $seasonLists) {

#reset some stuff for some reason? weird bugs otherwise
{$showName=$null
$episodeDLPath = $null
$outputArgs = $null
$listPath = $null
$listSource = $null
$ytDlpArgs = $null}

#get the show/season name from the text file
{$seasonFile = $txtfile.FullName
$showName = $txtfile.basename
if($showName.Length -gt 3){
  $seasonNumber = $showName.Substring($showName.Length - 3) # returns "def"
} else {
  $seasonNumber = "SXX"
}}

#set the path to download to based on the show/season
{$seasonDLPath = Join-Path $DownloadBase $showName
Write-host $seasonDLPath
write-host $seasonFile}

#build the episode-specific arguments
{
$episodeDLPath = "`"$($seasonDLPath)\$($seasonNumber)EXX $($namingFormat)`"" # built output path for the current video, default to using detected season and episode XX
$outputArgs = "-o",$episodeDLPath #download each episode in a text file to a specific folder
$listPath = "`"$($seasonFile)`"" 
$listSource = "-a",$listPath #get video URLs to download from the current iterated text file
}

$ytDlpArgs = [string]::Concat($formatArgs,' ',$cookieArgs,' ',$subtitleArgs,' ',$outputArgs,' ',$listSource)
write-host "args:",$ytDlpArgs
write-host "===="

#run YT-DLP with the constructed arguments
try{
$runYTDlp = Start-Process -FilePath $ytDlpPath -argumentlist $ytDlpArgs -nonewwindow -wait -passthru
write-host "Finished downloading all episodes from",$showName
Move-Item -path $seasonfile -destination $InputDone
}
catch {
write-host "oops",$Error
}
finally {
write-host "//////"
}

}