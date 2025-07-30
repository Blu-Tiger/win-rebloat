param (
    [string]$ConfigPath = ".\config.toml",
    [switch]$GetInfo,
    [switch]$GetObjectConfig,
    [switch]$GetJsonConfig,
    $Config = $null,
    $OptionalSelect = $null
)

function Win-Rebloat {
    param (
        [switch]$GetInfo,
        [switch]$GetObjectConfig,
        [switch]$GetJsonConfig,
        [string]$ConfigPath = ".\config.toml",
        $Config = $null,
        $OptionalSelect = $null
    )

    
    if ($null -eq $Config){
        $Config = Get-Content -Path $ConfigPath -Raw
    }

    try {
        try {
            $configObject = $Config | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            Write-Host "Configuration string parsed as JSON." -ForegroundColor DarkGray
            $selectableAppsCategList = $configObject.selectable_apps.keys
            $appsCategList = $configObject.apps.keys
        }
        catch {
            if (-not (Get-Module -ListAvailable -Name "PSToml")) {
                Write-Output "Installing PSToml module..."
                Install-Module PSToml -Scope CurrentUser -Force -Confirm:$false
            }
            Import-Module PSToml
            try {
                $configObject = ConvertFrom-Toml $Config -ErrorAction Stop
            }
            catch {
                Throw "Unsupported configuration format!"
            }
            Write-Host "Configuration string parsed as TOML." -ForegroundColor DarkGray
            $selectableAppsCategList = $configObject.selectable_apps.PSObject.ImmediateBaseObject.keys
            $appsCategList = $configObject.apps.PSObject.ImmediateBaseObject.keys
        }

        $apps = $configObject.apps
        $selectableApps = $configObject.selectable_apps

        if ($null -ne $OptionalSelect) {
            $parsedSelect = Optional-Select-Parser $OptionalSelect
        }


        foreach ($appCateg in $selectableAppsCategList) {
            if ($null -ne $parsedSelect -and $parsedSelect.ContainsKey($appCateg)) {
                foreach ($app in $selectableApps.$appCateg) {
                    $app.selected = $false
                }
                foreach ($select in $parsedSelect[$appCateg]) {
                    foreach ($app in $selectableApps.$appCateg) {
                        if ($select.ToLower() -eq $app.name.ToLower()) {
                            $app.selected = $true
                        }
                    }
                }
            }
            else {
                foreach ($app in $selectableApps.$appCateg) {
                    if ($null -eq $app.selected) {
                        $app.selected = $false
                    }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to load config: $_"
        exit 1
    }

    if ($GetInfo) {
        Write-Host "`n=== Available Bloatware ===`n" -ForegroundColor Cyan

        Write-Host "`n= Defaults =`n" -ForegroundColor Magenta

        foreach ($appCateg in $appsCategList) {
            if ($apps.$appCateg.Count -eq 0) {
                Write-Host "  No applications available." -ForegroundColor Red
                continue
            }

            Write-Host ($appCateg.Substring(0, 1).ToUpper() + $appCateg.Substring(1) + ":") -ForegroundColor Green
            foreach ($app in $apps.$appCateg) {
                Write-Host "    - $($app.name)"
            }
            Write-Host ""
        }

        Write-Host "`n= Selectable =`n" -ForegroundColor Magenta

        foreach ($appCateg in $selectableAppsCategList) {
            if ($selectableApps.$appCateg.Count -eq 0) {
                Write-Host "  No applications available." -ForegroundColor Red
                continue
            }

            Write-Host ($appCateg.Substring(0, 1).ToUpper() + $appCateg.Substring(1) + ":") -ForegroundColor DarkGreen

            foreach ($app in $selectableApps.$appCateg) {
                if ($null -ne $app.selected -and $app.selected -eq $true) {
                    Write-Host "    - $($app.name) (selected)" -ForegroundColor Yellow
                }
                else {
                    Write-Host "    - $($app.name)"
                }
            }
            Write-Host ""
        }

        return
    }

    if ($GetObjectConfig) {
        Write-Output $configObject
        return
    }

    if ($GetJsonConfig) {
        Write-Output $configObject | ConvertTo-Json -Depth 10
        return
    }

    #Installation process

    $temp = Join-Path -Path $env:TEMP -ChildPath "rebloat"

    if (-not (Test-Path -Path $temp)) {
        New-Item -Path $temp -ItemType Directory
        Write-Host "Folder created: $temp"
    }

    foreach ($appCateg in $appsCategList) {
        if ($apps.$appCateg.Count -eq 0) {
            Write-Host "No applications available for category '$appCateg'." -ForegroundColor Red
            continue
        }

        foreach ($app in $apps.$appCateg) {
            $PartFilePath = Generate-PartialFilePath -App $app -DlDir $temp

            if ($app.type -eq "github") {
                $filePath = Download-From-Github -App $app -PartFilePath $PartFilePath
            }
            elseif ($app.type -eq "website") {
                $filePath = Download-From-Website -PartFilePath $PartFilePath -App $app
            }
            else {
                Write-Error "Unknown app type: '$($app.type)'"
                continue
            }

            if (-not (Test-Path -Path $filePath)) {
                Write-Error "Failed to download file for '$($app.name)'."
                continue
            }
            
            Write-Host "Installing '$($app.name)'..." -ForegroundColor Green

            switch ([System.IO.Path]::GetExtension($filePath).ToLower().Trim(".")) {
                "msi" { MSI-Installer -FilePath $filePath }
                "exe" { EXE-Installer -FilePath $filePath -App $app }
                "msixbundle" { MSIXBundle-Installer -FilePath $filePath }
                default { Write-Error "Unknown install file type: '$([System.IO.Path]::GetExtension($filePath).ToLower().Trim("."))'" }
            }
        }
        
    }

    foreach ($appCateg in $selectableAppsCategList) {
        if ($selectableApps.$appCateg.Count -eq 0) {
            Write-Host "No applications available for category '$appCateg'." -ForegroundColor Red
            continue
        }

        foreach ($app in $selectableApps.$appCateg) {
            if ($app.selected -ne $true) {
                continue
            }

            $PartFilePath = Generate-PartialFilePath -App $app -DlDir $temp

            if ($app.type -eq "github") {
                $filePath = Download-From-Github -App $app -PartFilePath $PartFilePath
            }
            elseif ($app.type -eq "website") {
                $filePath = Download-From-Website -PartFilePath $PartFilePath -App $app
            }
            else {
                Write-Error "Unknown app type: '$($app.type)'"
                continue
            }

            if (-not (Test-Path -Path $filePath)) {
                Write-Error "Failed to download file for '$($app.name)'."
                continue
            }

            Write-Host "Installing '$($app.name)'..." -ForegroundColor Green

            switch ([System.IO.Path]::GetExtension($filePath).ToLower().Trim(".")) {
                "msi" { MSI-Installer -FilePath $filePath }
                "exe" { EXE-Installer -FilePath $filePath -App $app }
                "msixbundle" { MSIXBundle-Installer -FilePath $filePath }
                default { Write-Error "Unknown install file type: '$([System.IO.Path]::GetExtension($filePath).ToLower().Trim("."))'" }
            }
        }
        
    }

    # Cleanup
    if (Test-Path -Path $temp) {
        try {
            Remove-Item -Path $temp -Recurse -Force
            Write-Host "Temporary files cleaned up." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to clean up temporary files: $_"
        }
    }
    else {
        Write-Host "No temporary files to clean up." -ForegroundColor Yellow
    }
}

function Generate-PartialFilePath {
    param (
        [object]$App,
        [string]$DlDir
    )
    $Name = $App.name
    $Name = $Name.ToLower()
    $Name = $Name -replace ' ', '_'
    $Name = $Name -replace '[\\\/:*?"<>|]', ''
    $Name = $Name.Trim()

    $partFilePath = Join-Path -Path $DlDir -ChildPath $Name

    return $partFilePath
}

function Optional-Select-Parser {
    param (
        $OptionalSelect
    )
    if ([string]::IsNullOrWhiteSpace($OptionalSelect)) {
        return @{}
    }

    $parsed = @{}
    $groups = $OptionalSelect -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    foreach ($group in $groups) {
        if ($group -match '^(.*?):(.*)$') {
            $key = $matches[1].Trim()
            $values = $matches[2].Trim() -split ':' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $parsed[$key] = $values
        }
        else {
            $parsed[$group] = @()
        }
    }

    return $parsed
}

function Download-From-Github {
    param (
        [object]$App,
        [string]$PartFilePath
    )
    try {
        $url = "https://api.github.com/repos/$($App.repo)/releases/latest"
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "User-Agent" = "PowerShell" }

        if ($response -eq $null -or $response.Count -eq 0) {
            Write-Error "No files found in the repository or failed to retrieve data."
            return
        }

        $filesToDownload = $response.assets | Where-Object { $_.name -match $App.file_pattern }

        if ($filesToDownload.Count -eq 0) {
            Write-Host "No files matched the pattern '$($App.file_pattern)'."
            return
        }

        $file = $filesToDownload[0]
        $fileUrl = $file.browser_download_url

        Write-Host "Downloading '$($file.name)' from GitHub..."

        $filePath = ($PartFilePath + [System.IO.Path]::GetExtension($file.name))
        Invoke-WebRequest -Uri $fileUrl -OutFile $filePath

        Write-Host "'$($file.name)' downloaded successfully to '$filePath'."
        return $filePath
    }
    catch {
        Write-Error "Error occurred: $_"
    }
}

function Download-From-Website {
    param (
        [string]$PartFilePath,
        [object]$App
    )
    try {
        Invoke-Expression $App.get_url_function
        $fileUrl = New-Object System.Uri(Get-Url)
        $origFileName = [System.IO.Path]::GetFileName($fileUrl)
        $filePath = ($PartFilePath + [System.IO.Path]::GetExtension($origFileName))
        Write-Host "Downloading '$origFileName' from '$($fileUrl.Host)'..."
        Invoke-WebRequest -Uri $fileUrl -OutFile $filePath
        return $filePath
    }
    catch {
        Write-Error "Error occurred: $_"
    }
}


#Installers

function MSI-Installer {
    param (
        [string]$FilePath
    )
    try {
        Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "`"$FilePath`"", "/qn") -Wait
    }
    catch {
        Write-Error "Error occurred: $_"
    }
}

function EXE-Installer {
    param (
        [string]$FilePath,
        [object]$App
    )
    try {
        Start-Process -FilePath $FilePath -ArgumentList $App.install_args -Wait;
    }
    catch {
        Write-Error "Error occurred: $_"
    }
}

function MSIXBundle-Installer {
    param (
        [string]$FilePath
    )
    try {
        Add-AppxProvisionedPackage -Online -PackagePath $FilePath -SkipLicense
    }
    catch {
        Write-Error "Error occurred: $_"
    }
}

if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Win-Rebloat -GetObjectConfig:$GetObjectConfig -GetJsonConfig:$GetJsonConfig -GetInfo:$GetInfo -ConfigPath:$ConfigPath -Config:$Config -OptionalSelect:$OptionalSelect
}
