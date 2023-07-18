clear-host

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


$gconfig
write-host "---"
$config

$yP = $gconfig.ytDlpPath
$bp = $config.batchPath

write-host $yp " | " $bp