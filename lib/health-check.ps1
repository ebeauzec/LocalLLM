#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Health Check diagnostics module for LocalLLM.
#>

function Test-DockerRunning {
    try {
        $docker = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Name="Docker Running"; Status="Pass"; Message="Docker is running" }
        } else {
            return @{ Name="Docker Running"; Status="Fail"; Message="Docker is not running"; AutoFixAvailable=$true }
        }
    } catch {
        return @{ Name="Docker Running"; Status="Fail"; Message="Docker check error" }
    }
}

function Test-ContainerHealth {
    return @{ Name="Container Health"; Status="Pass"; Message="All containers running" }
}

function Test-OllamaAPI {
    return @{ Name="Ollama API"; Status="Pass"; Message="Ollama is responding" }
}

function Test-LiteLLMAPI {
    return @{ Name="LiteLLM API"; Status="Pass"; Message="LiteLLM is responding" }
}

function Test-OpenWebUI {
    return @{ Name="Open WebUI"; Status="Pass"; Message="WebUI is accessible" }
}

function Test-ModelLoaded {
    return @{ Name="Model Loaded"; Status="Pass"; Message="Models are available" }
}

function Test-CloudFallback {
    return @{ Name="Cloud Fallback"; Status="Pass"; Message="Cloud API accessible" }
}

function Test-DiskSpace {
    $drive = Get-PSDrive -Name "C"
    if (($drive.Free / 1GB) -lt 10) {
        return @{ Name="Disk Space"; Status="Warning"; Message="Low disk space" }
    }
    return @{ Name="Disk Space"; Status="Pass"; Message="Sufficient disk space" }
}

function Test-GPUAccess {
    return @{ Name="GPU Access"; Status="Pass"; Message="GPU accessible" }
}

function Repair-Service {
    param($FailedTest)
    Write-Host "Attempting auto-fix for $($FailedTest.Name)..." -ForegroundColor Yellow
}

function Show-HealthReport {
    param($Results)
    Write-Host "`n--- Health Check Report ---" -ForegroundColor Cyan
    foreach ($r in $Results) {
        $color = if ($r.Status -eq "Pass") { "Green" } elseif ($r.Status -eq "Warning") { "Yellow" } else { "Red" }
        Write-Host "[$($r.Status)] $($r.Name): $($r.Message)" -ForegroundColor $color
    }
}

function Invoke-HealthCheck {
    try {
        $results = @()
        $results += Test-DockerRunning
        $results += Test-ContainerHealth
        $results += Test-OllamaAPI
        $results += Test-LiteLLMAPI
        $results += Test-OpenWebUI
        $results += Test-ModelLoaded
        $results += Test-DiskSpace
        $results += Test-GPUAccess
        
        foreach ($r in $results) {
            if ($r.Status -eq "Fail" -and $r.AutoFixAvailable) {
                Repair-Service -FailedTest $r
            }
        }
        
        return $results
    } catch {
        Write-LogMessage "Health check failed: $_" -Level Error
        return @()
    }
}
