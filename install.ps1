param(
    [string]$Version = "",
    [string]$BaseUrl = "https://download.hengshi.com/cli",
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\HENGSHI\bin",
    [switch]$WithSkills,
    [string[]]$Agent = @(),
    [switch]$WhatIfMode
)

$ErrorActionPreference = "Stop"
$InstallSkills = $WithSkills.IsPresent -or $Agent.Count -gt 0

function Get-LatestVersion {
    param([string]$BaseUrl)

    $Metadata = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd("/") + "/latest.json")
    $ResolvedVersion = [string]$Metadata.version
    if ([string]::IsNullOrWhiteSpace($ResolvedVersion)) {
        throw "Could not resolve version from $BaseUrl/latest.json"
    }

    return $ResolvedVersion
}

function Get-AssetArch {
    function Resolve-AssetArchCandidate {
        param([AllowNull()][object]$Value)

        if ($null -eq $Value) {
            return $null
        }

        $Candidate = $Value.ToString().Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            return $null
        }

        switch ($Candidate) {
            "x64" { return "amd64" }
            "amd64" { return "amd64" }
            "arm64" { return "arm64" }
            default { throw "Unsupported Windows architecture: $Candidate" }
        }
    }

    $OsArchitectureProperty = $null
    if ($null -ne $PSVersionTable) {
        $OsArchitectureProperty = $PSVersionTable.PSObject.Properties["OSArchitecture"]
    }

    if ($null -ne $OsArchitectureProperty) {
        $ResolvedArch = Resolve-AssetArchCandidate $OsArchitectureProperty.Value
        if ($null -ne $ResolvedArch) {
            return $ResolvedArch
        }
    }

    try {
        $RuntimeArch = Resolve-AssetArchCandidate ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)
        if ($null -ne $RuntimeArch) {
            return $RuntimeArch
        }
    }
    catch {
        Write-Warning ("Failed to read RuntimeInformation.OSArchitecture: " + $_.Exception.Message)
    }

    Write-Warning "Could not determine Windows architecture from PowerShell runtime; defaulting to amd64."
    return "amd64"
}

function Resolve-HomeRelativePath {
    param([string]$PathSpec)

    if ($PathSpec.StartsWith("~/") -or $PathSpec.StartsWith('~\')) {
        $Relative = $PathSpec.Substring(2).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        return Join-Path $HOME $Relative
    }

    return $PathSpec
}

function Get-AgentManifestEntries {
    param([string]$ManifestPath)

    return Get-Content -Path $ManifestPath |
        Select-Object -Skip 1 |
        Where-Object { $_.Trim() -ne "" } |
        ForEach-Object {
            $Parts = $_ -split "`t"
            [pscustomobject]@{
                Agent       = $Parts[0]
                DisplayName = $Parts[1]
                GlobalPath  = $Parts[2]
            }
        }
}

function Get-SkillTargets {
    param(
        [object[]]$Entries,
        [string[]]$RequestedAgents
    )

    $SupportedAgents = ($Entries | ForEach-Object Agent) -join ", "
    $Seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $Targets = New-Object 'System.Collections.Generic.List[string]'

    if ($RequestedAgents.Count -gt 0) {
        foreach ($AgentName in $RequestedAgents) {
            $Entry = $Entries | Where-Object Agent -eq $AgentName | Select-Object -First 1
            if (-not $Entry) {
                throw "Unsupported -Agent '$AgentName'. Supported agents: $SupportedAgents"
            }

            $TargetPath = Resolve-HomeRelativePath $Entry.GlobalPath
            if ($Seen.Add($TargetPath)) {
                $Targets.Add($TargetPath)
            }
        }
    }
    else {
        foreach ($Entry in $Entries) {
            $TargetPath = Resolve-HomeRelativePath $Entry.GlobalPath
            $DetectDir = Split-Path -Parent $TargetPath
            if ((Test-Path -LiteralPath $DetectDir) -and $Seen.Add($TargetPath)) {
                $Targets.Add($TargetPath)
            }
        }
    }

    if ($Targets.Count -eq 0) {
        throw "Could not auto-detect any supported agent config directories. Re-run with -Agent <name>. Supported agents: $SupportedAgents"
    }

    return $Targets
}

function Install-BundledSkills {
    param(
        [string]$SkillsRoot,
        [string]$ManifestPath,
        [string]$LegacyPath,
        [string[]]$RequestedAgents
    )

    if (-not (Test-Path -LiteralPath $SkillsRoot)) {
        throw "Bundled skills directory missing from archive"
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Supported agents manifest missing from archive"
    }

    $Entries = Get-AgentManifestEntries -ManifestPath $ManifestPath
    $Targets = Get-SkillTargets -Entries $Entries -RequestedAgents $RequestedAgents
    $SkillDirs = @(Get-ChildItem -Path $SkillsRoot -Directory)

    if ($SkillDirs.Count -eq 0) {
        throw "No bundled skills found in archive"
    }

    $LegacyNames = @()
    if (Test-Path -LiteralPath $LegacyPath) {
        $LegacyNames = Get-Content -Path $LegacyPath | Where-Object { $_.Trim() -ne "" }
    }

    foreach ($TargetPath in $Targets) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null

        foreach ($LegacySkill in $LegacyNames) {
            $LegacySkillPath = Join-Path $TargetPath $LegacySkill
            if (Test-Path -LiteralPath $LegacySkillPath) {
                Remove-Item -LiteralPath $LegacySkillPath -Recurse -Force
            }
        }

        foreach ($SkillDir in $SkillDirs) {
            $Destination = Join-Path $TargetPath $SkillDir.Name
            if (Test-Path -LiteralPath $Destination) {
                Remove-Item -LiteralPath $Destination -Recurse -Force
            }
            Copy-Item -Path $SkillDir.FullName -Destination $Destination -Recurse -Force
        }

        Write-Output "Installed official skills to $TargetPath"
    }

    return $Targets
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-LatestVersion -BaseUrl $BaseUrl
}

$AssetArch = Get-AssetArch
$AssetName = "hengshi-cli-$Version-windows-${AssetArch}.zip"
$ArchiveUrl = "$BaseUrl/$Version/$AssetName"
$ChecksumUrl = "$BaseUrl/$Version/checksums.txt"
$LegacyBinaryPath = Join-Path $InstallDir "everest.exe"

if ($WhatIfMode) {
    Write-Output "VERSION=$Version"
    Write-Output "BASE_URL=$BaseUrl"
    Write-Output "ARCHIVE_URL=$ArchiveUrl"
    Write-Output "CHECKSUM_URL=$ChecksumUrl"
    Write-Output "INSTALL_DIR=$InstallDir"
    Write-Output "LEGACY_BINARY_PATH=$LegacyBinaryPath"
    Write-Output ("REMOVE_LEGACY_BINARY=" + ((Test-Path -LiteralPath $LegacyBinaryPath).ToString().ToLowerInvariant()))
    if ($InstallSkills) {
        Write-Output "WITH_SKILLS=true"
        if ($Agent.Count -gt 0) {
            Write-Output ("SKILLS_AGENTS=" + ($Agent -join ","))
        }
        else {
            Write-Output "SKILLS_AGENTS=auto-detect"
        }
        Write-Output "SKILLS_MODE=bundled-archive"
    }
    else {
        Write-Output "WITH_SKILLS=false"
    }
    exit 0
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hengshi-cli-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    $ArchivePath = Join-Path $TempDir $AssetName
    $ChecksumPath = Join-Path $TempDir "checksums.txt"

    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath
    Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath

    $ExpectedHash = Select-String -Path $ChecksumPath -Pattern ([regex]::Escape($AssetName) + '$') |
        Select-Object -First 1 |
        ForEach-Object { ($_ -split '\s+')[0] }

    if (-not $ExpectedHash) {
        throw "Missing checksum entry for $AssetName"
    }

    $ActualHash = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualHash -ne $ExpectedHash.ToLowerInvariant()) {
        throw "Checksum mismatch for $AssetName"
    }

    Expand-Archive -Path $ArchivePath -DestinationPath $TempDir -Force
    $Binary = Get-ChildItem -Path $TempDir -Recurse -File -Filter "hbi.exe" | Select-Object -First 1
    if (-not $Binary) {
        throw "Could not find hbi.exe in extracted archive"
    }
    $BundledSkillsDir = Join-Path $TempDir "skills"
    $SupportedAgentsPath = Join-Path $TempDir "supported-agents.tsv"
    $LegacySkillsPath = Join-Path $TempDir "legacy-skill-names.txt"

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path $Binary.FullName -Destination (Join-Path $InstallDir "hbi.exe") -Force

    Write-Output "Installed hbi.exe to $InstallDir"
    if (Test-Path -LiteralPath $LegacyBinaryPath) {
        Remove-Item -LiteralPath $LegacyBinaryPath -Force
        Write-Output "Removed legacy everest.exe from $LegacyBinaryPath"
    }
    Write-Output "If needed, add $InstallDir to your PATH."

    $ResolvedSkillTargets = @()
    if ($InstallSkills) {
        $ResolvedSkillTargets = Install-BundledSkills -SkillsRoot $BundledSkillsDir -ManifestPath $SupportedAgentsPath -LegacyPath $LegacySkillsPath -RequestedAgents $Agent
    }

    $ManagedBinaryPath = Join-Path $InstallDir "hbi.exe"
    $StateArgs = @(
        "internal", "updater", "write-state",
        "--installer-kind", "powershell",
        "--install-dir", $InstallDir,
        "--managed-binary-path", $ManagedBinaryPath
    )
    if ($InstallSkills) {
        $StateArgs += "--with-skills"
        if ($Agent.Count -gt 0) {
            $StateArgs += @("--skills-target-mode", "explicit")
            foreach ($RequestedAgent in $Agent) {
                $StateArgs += @("--agent", $RequestedAgent)
            }
        }
        else {
            $StateArgs += @("--skills-target-mode", "auto-detect")
        }

        foreach ($TargetPath in $ResolvedSkillTargets) {
            $StateArgs += @("--resolved-skill-target", $TargetPath)
        }
    }

    & $ManagedBinaryPath @StateArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to persist updater state"
    }
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}
