param(
    [switch]$Setup,
    [string]$ConfigPath = "$env:USERPROFILE\.mcp-onedrive.json"
)

$ErrorActionPreference = 'Stop'

function Get-OneDriveFolders {
    $folders = @()
    $homePath = [Environment]::GetFolderPath('UserProfile')

    if (Test-Path -LiteralPath $homePath) {
        Get-ChildItem -LiteralPath $homePath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*OneDrive*' } |
            ForEach-Object { $folders += $_.FullName }
    }

    return ($folders | Sort-Object -Unique)
}

function Get-StringPreview {
    param([string]$Value)

    if ($null -eq $Value) { return '' }
    return $Value
}

function Get-FilesInFolder {
    param(
        [Parameter(Mandatory)] [string]$FolderPath,
        [int]$MaxDepth = 3,
        [int]$CurrentDepth = 0
    )

    $items = @()

    if ($CurrentDepth -ge $MaxDepth) {
        return $items
    }

    if (-not (Test-Path -LiteralPath $FolderPath)) {
        return $items
    }

    $children = Get-ChildItem -LiteralPath $FolderPath -Force -ErrorAction SilentlyContinue

    foreach ($child in $children) {
        if ($child.PSIsContainer) {
            if ($child.Name.StartsWith('.')) { continue }

            $items += [ordered]@{
                name = $child.Name
                path = $child.FullName
                type = 'folder'
            }

            $items += Get-FilesInFolder -FolderPath $child.FullName -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
        }
        else {
            $items += [ordered]@{
                name = $child.Name
                path = $child.FullName
                size = $child.Length
                type = 'file'
            }
        }
    }

    return $items
}

function Get-FileText {
    param([Parameter(Mandatory)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return "Error reading file: file not found"
    }

    try {
        $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        return $content
    }
    catch {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            $sample = $bytes[0..([Math]::Min($bytes.Length - 1, 511))]
            $hasNull = $false
            foreach ($b in $sample) {
                if ($b -eq 0) {
                    $hasNull = $true
                    break
                }
            }

            if ($hasNull) {
                return "[Binary file: $FilePath]"
            }

            return [System.Text.Encoding]::Default.GetString($bytes)
        }
        catch {
            return "Error reading file: $($_.Exception.Message)"
        }
    }
}

function Write-JsonLine {
    param([Parameter(Mandatory)]$Object)
    $json = $Object | ConvertTo-Json -Compress -Depth 20
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function Run-Setup {
    Write-Host ""
    Write-Host "=== OneDrive Local File MCP Server Setup (PowerShell) ==="
    Write-Host ""

    $folders = Get-OneDriveFolders

    if (-not $folders -or $folders.Count -eq 0) {
        Write-Host "No OneDrive folders auto-detected."
        $manual = Read-Host "Enter a folder path to expose (or leave blank to cancel)"

        if ([string]::IsNullOrWhiteSpace($manual)) {
            Write-Host "Cancelled."
            return
        }

        if (-not (Test-Path -LiteralPath $manual)) {
            Write-Host "Path not found: $manual"
            return
        }

        $selected = @($manual)
    }
    else {
        Write-Host "Found $($folders.Count) OneDrive folder(s):"
        Write-Host ""

        for ($i = 0; $i -lt $folders.Count; $i++) {
            Write-Host "  $($i + 1). $($folders[$i])"
        }

        Write-Host ""
        Write-Host "Which folders do you want to include? (comma-separated numbers, or all)"
        $response = (Read-Host ">").Trim().ToLowerInvariant()

        if ($response -eq 'all') {
            $selected = $folders
        }
        else {
            $selected = @()
            $parts = $response -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            foreach ($part in $parts) {
                $idx = 0
                if ([int]::TryParse($part, [ref]$idx)) {
                    $zeroIdx = $idx - 1
                    if ($zeroIdx -ge 0 -and $zeroIdx -lt $folders.Count) {
                        $selected += $folders[$zeroIdx]
                    }
                }
            }

            if (-not $selected -or $selected.Count -eq 0) {
                Write-Host "No valid selection. Defaulting to all folders."
                $selected = $folders
            }
        }
    }

    Write-Host ""
    Write-Host "Selected $($selected.Count) folder(s):"
    $selected | ForEach-Object { Write-Host "  - $_" }

    $cfg = [ordered]@{
        enabled_folders = $selected
        max_depth = 3
    }

    $cfgDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path -LiteralPath $cfgDir)) {
        New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    }

    $cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8

    Write-Host ""
    Write-Host "Config saved to $ConfigPath"
}

function Load-Config {
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            return Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Error "Invalid config file: $ConfigPath"
            exit 1
        }
    }

    return [pscustomobject]@{
        enabled_folders = @(Get-OneDriveFolders)
        max_depth = 3
    }
}

function Run-Server {
    $cfg = Load-Config

    $enabledFolders = @($cfg.enabled_folders)
    $maxDepth = if ($cfg.max_depth) { [int]$cfg.max_depth } else { 3 }

    if (-not $enabledFolders -or $enabledFolders.Count -eq 0) {
        [Console]::Error.WriteLine("No folders configured. Run with -Setup first.")
        exit 1
    }

    [Console]::Error.WriteLine("Serving folders: $($enabledFolders.Count)")

    while ($true) {
        $line = [Console]::In.ReadLine()
        if ($null -eq $line) { break }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        try {
            $msg = $line | ConvertFrom-Json -ErrorAction Stop
            $method = Get-StringPreview $msg.method
            $id = $msg.id
            $params = $msg.params

            $response = [ordered]@{
                jsonrpc = '2.0'
                id = $id
            }

            switch ($method) {
                'list_folders' {
                    $response.result = [ordered]@{ folders = $enabledFolders }
                }
                'list_files' {
                    $folder = if ($params -and $params.folder) { [string]$params.folder } else { $enabledFolders[0] }
                    $files = Get-FilesInFolder -FolderPath $folder -MaxDepth $maxDepth
                    $response.result = [ordered]@{ files = $files }
                }
                'read_file' {
                    if (-not $params -or -not $params.path) {
                        $response.error = [ordered]@{ code = -32602; message = 'Missing required param: path' }
                    }
                    else {
                        $content = Get-FileText -FilePath ([string]$params.path)
                        $response.result = [ordered]@{ content = $content }
                    }
                }
                default {
                    $response.error = [ordered]@{ code = -32601; message = 'Method not found' }
                }
            }

            Write-JsonLine -Object $response
        }
        catch {
            $err = [ordered]@{
                jsonrpc = '2.0'
                error = [ordered]@{
                    code = -32603
                    message = $_.Exception.Message
                }
            }
            Write-JsonLine -Object $err
        }
    }
}

if ($Setup) {
    Run-Setup
    exit 0
}

Run-Server
