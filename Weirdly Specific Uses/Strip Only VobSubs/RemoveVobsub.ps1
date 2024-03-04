#=================================================#
#              STRIP OUT VOBSUBS                  #
#=================================================#
#region introduction
##############################################
#
# Sometimes something ripped from a DVD may have really ugly, yellow, giant, 
# image-based VOBSUB subtitles that yuou want to get rid of. They're gross.
# There's lots of ways to just nuke all subtitles, but what if, say, you want to 
# keep some of them? Like keep an English SRT and get rid of the VOBSUB, for example.
# You can do it manually in MKVToolNix which sucks or batchwise with this baby.
# You will want to make sure that all of the files are structured the same way before proceeding.
#
# To start, open one file in MKVToolNix and manuall set the tracks you wish to keep and 
# exclude. Go to |Multiplexer > Show Command Line|, set the escape option to Don't Escape,
# and copy the command. It should look something like this:
# {mkvMergePath} --output "{outputPath}" --subtitle-tracks 3 --language 0:en --language 1:en --sub-charset 3:UTF-8 --language 3:en "{inputPath}" --track-order 0:0,0:1,0:3
#
#
# Edit the config, and paste everything from between the output and input name to the 'trackDetails' argument.
# Paste everything after the input name to the 'trackOrder' argument.
# Edit the working path to the parent folder where your files are contained. Files should be within subfolders of this folder.
# The processed files will be saved in a subfolder called "done" of the file's original folder, with the same name.
# After validating, you can safely move the new file and overwrite the original.
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
$host.ui.RawUI.WindowTitle = “Strip Only VobSubs - PlexPals”
# find and read the global config
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

$mkvMergePath = $gconfig.mkvMergePath
$workingPath = $config.workingPath
$doneFolderName = "done"
$trackLayout = $config.trackDetails
$trackOrder = $config.trackOrder
$baseArgString = "-o `"{0}`" {1} `"{2}`" {3}"
#endregion


#=================================================#
#                  EXECUTION                      #
#=================================================#

# get a list of all subfolders in the specified working path
$folderList = get-childitem $workingPath -Directory

#iterate through each folder
foreach ($folder in $folderList) {

    $fullFolderPath = $folder.FullName

    #reset values
    $donePath = $null
    $mkvMergeArg = $null

    #build output folder
    $donePath = Join-Path $fullFolderPath $doneFolderName
        #make sure done folder exists
        If(!(test-path -PathType container $donePath)) 
            {
            New-Item -ItemType Directory -Path $donePath
            }

    #get the contents of each child folder
    $subfolderContents = Get-ChildItem $fullFolderPath -Attributes !Directory -filter *.mkv

    #iterate through the videos
    foreach ($mkv in $subfolderContents) {
        $inputPath = $mkv.FullName
        #build output path to \done
        $outputPath = Join-Path $donePath $mkv.Name

        # build mkvmerge argument
        $mkvMergeArg = [string]::Format($baseArgString,$outputPath,$trackLayout,$inputPath,$trackOrder)
        # remove any double spaces that may have snuck in
        $mkvMergeArg = $mkvMergeArg.replace('  ',' ')
        
        # execute mkvmerge
        Start-Process -FilePath $mkvMergePath -ArgumentList $mkvMergeArg -nonewwindow -passthru -wait
        }

}