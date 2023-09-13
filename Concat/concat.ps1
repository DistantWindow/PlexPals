#=================================================#
#           CONCATENATE VIDEO FILES               #
#=================================================#

##############################################
# This Pal will read a list of file from a specified folder, and then go through each of those
# and concatenate them (in alphabetical order) to a single output file.
#
# Start by placing all of the files you want to concatenate in one place, named so they are in the
# desired alphabetical order. They shoudl be the only files in this folder.
# Indicate the path to this folder in the config.ini file.
# Right-click the script and Run with Powershell, and it will process all listed items.
#
# After completion, the input files will be moved to the recycle bin, where they can be restored as needed.
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

#add visual basic so we can send fiels to recylce bin
Add-Type -AssemblyName Microsoft.VisualBasic

# assign config values to script variables
$ffmpeg = $gConfig.ffmpegLocation
$inputFolder = $config.inputPath
$burnAfterReading = $config.burnAfterReading
$outputFilename = $config.outputFilename

#provide some inputs
$inputFileName = "input.txt"
$fileCount=0
#build the paths
$inputFilePath = join-path $inputFolder $inputFileName
$outputPathNoQ = join-path $inputFolder $outputFilename
$outputPath = "`"$($outputPathNoQ)`""
$outputPathSQ = "`'$($outputPathNoQ)`'"

#if an existing input list exists, delete it
if (test-path -path $inputFilePath -pathtype Leaf) {
write-host "Existing input.txt file found, sending to recylce bin so a new one can be generated"
try {
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($inputFilePath,'OnlyErrorDialogs','SendToRecycleBin')
} catch {
write-host "Ran into some issue deleting input.txt. Please validate output."
}
}

#get all the files in the provided folder
$inputFiles = Get-ChildItem $inputFolder #-Filter *.mp4

#add each file in the input folder to the list
foreach ($file in $inputFiles) {
$fullFilePath = $file.FullName
if ($file.Name -eq $outputFilename) {continue}
$currLine = "file '$($fullFilePath)'"
write-host $currLine
Add-Content $inputFilePath $currLine
$fileCount++
}
write-host $fileCount
#throw an exception if there's only input file
If ($fileCount -le 1){throw "Only one input file found. Concatenation requries at least two files."}

#build the arguments for ffmpeg
$argString = "-fflags +genpts -f concat -safe 0 -i $($inputFilePath) -c copy $outputPath"
write-host $argString

#run ffmpeg and, in case of an error, keep the powershell console from closing
try {
Start-Process -FilePath $ffmpeg -ArgumentList $argString -NoNewWindow -PassThru -wait

write-host $outputPathSQ
if (test-path -literalpath $outputPathNoQ -pathtype Leaf) {
write-host "Concatenation finished successfully."
} elseif (-not(test-path -literalpath $outputPathNoQ -pathtype Leaf)) {
write-host "Ran into some problem while concatenating the files. Validate output."
}

} catch {
$burnAfterReading = $false
write-host "oops" error
read-host "Press enter to exit"
}

#see if the output file exists
$outputExists = test-path -literalpath $outputPathNoQ -pathtype Leaf
if ($outputExists -eq $false -and $burnAfterReading -eq $true) {
write-host "Output file was not found at $($outputPath); setting burnAfterReading to false."
$burnAfterReading=$false
}

#delete the generated text file
try{
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($inputFilePath,'OnlyErrorDialogs','SendToRecycleBin')
} catch {write-host "Couldn't"}

#delete the input file if the flag is true
if ($burnAfterReading -eq $true) {
write-host "Burn After Reading is true. Deleting input files..."
foreach ($file in $inputFiles) {
write-host $file
if ($file -like "*$outputFilename*") {continue}
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($file.FullName,'OnlyErrorDialogs','SendToRecycleBin')
}
}
Read-Host -Prompt "Press Enter to exit"