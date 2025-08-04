#!/usr/bin/env pwsh
# complete-build.ps1 - Complete automated ISO build with SetupComplete integration
# This script runs the entire process: build autounattend -> inject -> integrate SetupComplete -> build ISO

param(
    [string]$SourceIsoPath,
    [string]$OutputIsoPath,
    [string]$IsoLabel = "CloudIT_Windows_AzureAD"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        "STEP" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level "STEP"
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Log "This script must be run as Administrator" -Level "ERROR"
        return $false
    }
    
    # Check for Node.js (for npm commands)
    try {
        $null = Get-Command npm -ErrorAction Stop
        Write-Log "Found npm" -Level "SUCCESS"
    } catch {
        Write-Log "npm not found. Please install Node.js" -Level "ERROR"
        return $false
    }
    
    # Check for TypeScript compiler
    try {
        $null = Get-Command tsc -ErrorAction Stop
        Write-Log "Found TypeScript compiler" -Level "SUCCESS"
    } catch {
        Write-Log "TypeScript compiler not found. Installing..." -Level "WARNING"
        npm install -g typescript
    }
    
    return $true
}

function Invoke-Step {
    param(
        [string]$StepName,
        [scriptblock]$ScriptBlock
    )
    
    Write-Log "=== STEP: $StepName ===" -Level "STEP"
    $startTime = Get-Date
    
    try {
        $result = & $ScriptBlock
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($result) {
            Write-Log "$StepName completed successfully in $($duration.TotalSeconds.ToString('F1'))s" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "$StepName failed" -Level "ERROR"
            return $false
        }
    } catch {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Log "$StepName failed after $($duration.TotalSeconds.ToString('F1'))s: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
function Main {
    $buildStartTime = Get-Date
    Write-Log "Starting complete CloudIT Windows ISO build process..." -Level "SUCCESS"
    Write-Log "This will create an ISO with Azure AD Join and automatic post-OOBE restart" -Level "SUCCESS"
    
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Determine project paths
    if ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } elseif ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } else {
        $scriptDir = Get-Location
    }
    $projectRoot = Split-Path -Parent $scriptDir
    
    # Set default paths if not provided
    if (-not $SourceIsoPath) {
        $SourceIsoPath = Join-Path $projectRoot "iso\source\windows.iso"
    }
    
    if (-not $OutputIsoPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputIsoPath = Join-Path $projectRoot "iso\result\CloudIT_AzureAD_$timestamp.iso"
    }
    
    $extractedPath = Join-Path $projectRoot "iso\extracted"
    
    Write-Log "Build Configuration:" -Level "SUCCESS"
    Write-Log "  Source ISO: $SourceIsoPath"
    Write-Log "  Output ISO: $OutputIsoPath"
    Write-Log "  Extracted Path: $extractedPath"
    Write-Log "  ISO Label: $IsoLabel"
    Write-Log ""
    
    # Step 1: Extract ISO
    $success = Invoke-Step "Extract Source ISO" {
        if (-not (Test-Path $SourceIsoPath)) {
            Write-Log "Source ISO not found: $SourceIsoPath" -Level "ERROR"
            return $false
        }
        
        $extractScript = Join-Path $scriptDir "extract-iso.ps1"
        if (-not (Test-Path $extractScript)) {
            Write-Log "Extract script not found: $extractScript" -Level "ERROR"
            return $false
        }
        
        & powershell.exe -File $extractScript -IsoPath $SourceIsoPath -ExtractPath $extractedPath
        return $LASTEXITCODE -eq 0
    }
    if (-not $success) { exit 1 }
    
    # Step 2: Build autounattend.xml
    $success = Invoke-Step "Build autounattend.xml from passes" {
        Set-Location $projectRoot
        & npm run build-xml
        return $LASTEXITCODE -eq 0
    }
    if (-not $success) { exit 1 }
    
    # Step 3: Inject autounattend.xml and SetupComplete.cmd
    $success = Invoke-Step "Inject autounattend.xml and SetupComplete.cmd" {
        $injectScript = Join-Path $scriptDir "inject-autounattend.ps1"
        if (-not (Test-Path $injectScript)) {
            Write-Log "Inject script not found: $injectScript" -Level "ERROR"
            return $false
        }
        
        $autounattendPath = Join-Path $projectRoot "unattended\build\autounattend.xml"
        & powershell.exe -File $injectScript -ExtractedIsoPath $extractedPath -AutounattendPath $autounattendPath
        return $LASTEXITCODE -eq 0
    }
    if (-not $success) { exit 1 }
    
    # Step 4: Verify SetupComplete.cmd integration
    $success = Invoke-Step "Verify SetupComplete.cmd Integration" {
        $setupCompletePath = Join-Path $extractedPath "`$OEM`$\`$`$\Setup\Scripts\SetupComplete.cmd"
        if (Test-Path $setupCompletePath) {
            Write-Log "SetupComplete.cmd found at: $setupCompletePath" -Level "SUCCESS"
            $fileSize = (Get-Item $setupCompletePath).Length
            Write-Log "File size: $fileSize bytes" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "SetupComplete.cmd not found - post-OOBE restart will not work" -Level "ERROR"
            return $false
        }
    }
    if (-not $success) { 
        Write-Log "Continuing without SetupComplete.cmd..." -Level "WARNING"
    }
    
    # Step 5: Build final ISO
    $success = Invoke-Step "Build Final ISO" {
        $buildScript = Join-Path $scriptDir "build-iso.ps1"
        if (-not (Test-Path $buildScript)) {
            Write-Log "Build script not found: $buildScript" -Level "ERROR"
            return $false
        }
        
        & powershell.exe -File $buildScript -ExtractedIsoPath $extractedPath -OutputIsoPath $OutputIsoPath -IsoLabel $IsoLabel
        return $LASTEXITCODE -eq 0
    }
    if (-not $success) { exit 1 }
    
    # Final verification and summary
    $buildEndTime = Get-Date
    $totalDuration = $buildEndTime - $buildStartTime
    
    Write-Log ""
    Write-Log "========================================" -Level "SUCCESS"
    Write-Log "BUILD COMPLETED SUCCESSFULLY!" -Level "SUCCESS"
    Write-Log "========================================" -Level "SUCCESS"
    Write-Log "Total build time: $($totalDuration.ToString('hh\:mm\:ss'))" -Level "SUCCESS"
    Write-Log ""
    Write-Log "Output ISO: $OutputIsoPath" -Level "SUCCESS"
    
    if (Test-Path $OutputIsoPath) {
        $isoSize = (Get-Item $OutputIsoPath).Length
        $isoSizeMB = [math]::Round($isoSize / 1MB, 2)
        Write-Log "ISO Size: $isoSizeMB MB" -Level "SUCCESS"
    }
    
    Write-Log ""
    Write-Log "FEATURES INCLUDED:" -Level "SUCCESS"
    Write-Log "Automated Windows installation" -Level "SUCCESS"
    Write-Log "Region: Israel (he-IL) with English keyboard (en-US)" -Level "SUCCESS"
    Write-Log "Azure AD / Microsoft account sign-in required" -Level "SUCCESS"
    Write-Log "All privacy settings disabled" -Level "SUCCESS"
    Write-Log "Enterprise image selection (Windows 10/11 Enterprise)" -Level "SUCCESS"
    Write-Log "Automatic restart after OOBE completes" -Level "SUCCESS"
    Write-Log "Clean login screen for end users" -Level "SUCCESS"
    Write-Log ""
    Write-Log "DEPLOYMENT FLOW:" -Level "SUCCESS"
    Write-Log "1. Boot from ISO → Automated Windows installation" -Level "SUCCESS"
    Write-Log "2. OOBE starts → Region/keyboard set to Israel/English" -Level "SUCCESS"
    Write-Log "3. User signs in with Azure AD/Microsoft account" -Level "SUCCESS"
    Write-Log "4. Device joins Azure AD and applies policies" -Level "SUCCESS"
    Write-Log "5. SetupComplete.cmd runs → Automatic restart" -Level "SUCCESS"
    Write-Log "6. Clean login screen → End user can sign in" -Level "SUCCESS"
    Write-Log ""
    Write-Log "The ISO is ready for deployment!" -Level "SUCCESS"
    
    exit 0
}

# Run main function
Main
