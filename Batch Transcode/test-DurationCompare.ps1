$ffprobe = "C:\Project\concat\ffprobe.exe"
$testVar= "hello"
$doneFolder = "done"

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
    $inputSize = (Get-ChildItem $inputPath).Length
    $inputKB = $([math]::Round($inputSize/1KB,2))
    $outputSize= (Get-ChildItem $outputPath).Length
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
#example usage |    
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
    $inputMovedTo = $originalSentTo
    } else {
    
    #get the durations
    $durationMatch, $inputDuration, $outputDuration = Compare-VideoDurations -inputPath $startingFile -outputPath $finishedFile -ffprobePath $ffprobePath
    #get the sizes
    $inputKB, $outputKB, $diffPercent = compare-FileSize -inputPath $inputFile -outputPath $outputFile

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



# Example usage
$inputFile = "C:\Project\PlexPals\Batch Transcode\test\done\test.mkv"
$outputFile = "C:\Project\PlexPals\Batch Transcode\test\out\test.mkv"
$logFilePath = "outputLog.csv"

<#
#$durationMatch, $inputDuration, $outputDuration = Compare-VideoDurations -inputPath $inputFile -outputPath $outputFile



$inputKB, $outputKB, $diffPercent = compare-FileSize -inputPath $inputFile -outputPath $outputFile
write-host $inputKB "KB"
write-host $outputKB "KB"
write-host "$($diffPercent)%"
if ($diffPercent -gt 100) {
    write-host "$($diffPercent)% - bigger"
    }elseif ($diffPercent -eq 100) {
     write-host "same"
     } else {
     write-host "$($diffPercent)% - smaller"
     }


#$moveResult, $finalPlace, $finalCleanupSetting = move-finishedFile -cleanupOption 1 -startingFile $inputFile -finishedFile $outputFile
$moveResult, $finalPlace = move-finishedFile -cleanupOption 2 -startingFile $inputFile -finishedFile $outputFile
#$moveResult, $finalPlace, $finalCleanupSetting = move-finishedFile -cleanupOption 2 -startingFile $inputFile -finishedFile $outputFile
#$moveResult, $finalPlace, $finalCleanupSetting = move-finishedFile -cleanupOption 3 -startingFile $inputFile -finishedFile $outputFile
write-host "result - $($moverResult)"
write-host $finalPlace
write-host $finalCleanupSetting
#>
$startTimeStr = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
$endTimeStr = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"
write-TranscodeLog -logPath $logFilePath -startingFile $inputFile -finishedFile $outputFile -ffprobePath $ffprobe -startTime $startTimeStr -endTime $endTimeStr
write-TranscodeLog -logPath $logFilePath -startingFile $inputFile -originalSentTo "Done"