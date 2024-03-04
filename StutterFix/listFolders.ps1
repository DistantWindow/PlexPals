$host.ui.RawUI.WindowTitle = “List Folders - PlexPals”

clear-host
$workpath = "J:\Utilities\Rename"
$outputPath = "remuxList.txt"
$files = Get-ChildItem $workpath -Directory
foreach ($item in $files) {
write-host $item.fullname
$currFile = $item.FullName
Out-File $outputPath -InputObject $currFile -Append -Encoding UTF8
}