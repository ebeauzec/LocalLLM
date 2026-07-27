#Requires -Version 5.1
# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# Project: LocalLLM - Self-Contained Local AI Platform

<#
.SYNOPSIS
Health Check diagnostics module for LocalLLM.
.DESCRIPTION
Provides robust checks for all LocalLLM services, including auto-fix capabilities.
#>

$script:ProjectRoot = $PSScriptRoot | Split-Path -Parent

function Test-DockerRunning {
    try {
        $docker = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Name="Docker Running"; Status="Pass"; Message="Docker daemon is running"; AutoFixAvailable=$false }
        } else {
            return @{ Name="Docker Running"; Status="Fail"; Message="Docker is not running"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
        }
    } catch {
        return @{ Name="Docker Running"; Status="Fail"; Message="Docker check error"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    }
}

function Test-ContainerHealth {
    try {
        $composePath = Join-Path $script:ProjectRoot "config\docker-compose.yml"
        if (-not (Test-Path $composePath)) {
            return @{ Name="Container Health"; Status="Warning"; Message="docker-compose.yml not found"; AutoFixAvailable=$false }
        }
        
        $containers = docker compose -f $composePath --project-directory $script:ProjectRoot ps --format json 2>$null | ConvertFrom-Json
        $failed = @()
        foreach ($c in $containers) {
            if ($c.State -ne "running") {
                $failed += $c.Name
            }
        }
        
        if ($failed.Count -gt 0) {
            return @{ Name="Container Health"; Status="Fail"; Message="Containers down: $($failed -join ', ')"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
        }
        
        return @{ Name="Container Health"; Status="Pass"; Message="All containers running"; AutoFixAvailable=$false }
    } catch {
        return @{ Name="Container Health"; Status="Fail"; Message="Failed to check container health"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    }
}

function Test-OllamaAPI {
    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/' -TimeoutSec 5
        if ($response -match "Ollama is running") {
            return @{ Name="Ollama API"; Status="Pass"; Message="Ollama is responding"; AutoFixAvailable=$false }
        }
        return @{ Name="Ollama API"; Status="Fail"; Message="Ollama unexpected response"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    } catch {
        return @{ Name="Ollama API"; Status="Fail"; Message="Ollama unreachable"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    }
}

function Test-LiteLLMAPI {
    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:4000/health' -TimeoutSec 5
        return @{ Name="LiteLLM API"; Status="Pass"; Message="LiteLLM is responding"; AutoFixAvailable=$false }
    } catch {
        return @{ Name="LiteLLM API"; Status="Fail"; Message="LiteLLM unreachable"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    }
}

function Test-OpenWebUI {
    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:3100/' -TimeoutSec 5 -UseBasicParsing
        return @{ Name="Open WebUI"; Status="Pass"; Message="WebUI is accessible"; AutoFixAvailable=$false }
    } catch {
        return @{ Name="Open WebUI"; Status="Fail"; Message="WebUI unreachable"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    }
}

function Test-ModelLoaded {
    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -TimeoutSec 5
        if ($response.models -and $response.models.Count -gt 0) {
            return @{ Name="Model Loaded"; Status="Pass"; Message="$($response.models.Count) models available"; AutoFixAvailable=$false }
        }
        return @{ Name="Model Loaded"; Status="Warning"; Message="No models loaded"; AutoFixAvailable=$true; AutoFixAttempted=$false; AutoFixResult=$null }
    } catch {
        return @{ Name="Model Loaded"; Status="Fail"; Message="Failed to check models"; AutoFixAvailable=$false }
    }
}

function Test-CloudFallback {
    $results = @()
    try {
        $response = Invoke-WebRequest -Uri 'https://api.openai.com/' -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
        $results += "OpenAI reachable"
    } catch { $results += "OpenAI unreachable" }
    
    try {
        $response = Invoke-WebRequest -Uri 'https://api.anthropic.com/' -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
        $results += "Anthropic reachable"
    } catch { $results += "Anthropic unreachable" }
    
    return @{ Name="Cloud Fallback"; Status="Pass"; Message=($results -join ", "); AutoFixAvailable=$false }
}

function Test-DiskSpace {
    try {
        $driveLetter = (Get-Item $script:ProjectRoot).Root.Substring(0,1)
        $drive = Get-PSDrive -Name $driveLetter
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        if ($freeGB -lt 10) {
            return @{ Name="Disk Space"; Status="Warning"; Message="Low disk space on drive $driveLetter ($freeGB GB free)"; AutoFixAvailable=$false }
        }
        return @{ Name="Disk Space"; Status="Pass"; Message="Sufficient disk space ($freeGB GB free)"; AutoFixAvailable=$false }
    } catch {
        return @{ Name="Disk Space"; Status="Warning"; Message="Could not verify disk space"; AutoFixAvailable=$false }
    }
}

function Test-GPUAccess {
    try {
        $smi = nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Name="GPU Access"; Status="Pass"; Message="NVIDIA GPU accessible"; AutoFixAvailable=$false }
        }
        return @{ Name="GPU Access"; Status="Warning"; Message="NVIDIA GPU not accessible via nvidia-smi"; AutoFixAvailable=$false }
    } catch {
        return @{ Name="GPU Access"; Status="Warning"; Message="nvidia-smi not found or failed"; AutoFixAvailable=$false }
    }
}

function Repair-Service {
    [CmdletBinding()]
    param($FailedTest)
    
    Write-Host "Attempting auto-fix for $($FailedTest.Name)..." -ForegroundColor Yellow
    $FailedTest.AutoFixAttempted = $true
    
    try {
        switch ($FailedTest.Name) {
            "Docker Running" {
                Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                Write-Host "Waiting 60 seconds for Docker to start..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                $FailedTest.AutoFixResult = "Started Docker Desktop"
            }
            "Container Health" {
                $composePath = Join-Path $script:ProjectRoot "config\docker-compose.yml"
                Push-Location $script:ProjectRoot
                docker compose -f $composePath --project-directory $script:ProjectRoot up -d
                Pop-Location
                $FailedTest.AutoFixResult = "Ran docker compose up"
            }
            "Ollama API" {
                docker restart localllm-ollama
                Start-Sleep -Seconds 5
                $FailedTest.AutoFixResult = "Restarted localllm-ollama container"
            }
            "LiteLLM API" {
                docker restart localllm-litellm
                Start-Sleep -Seconds 5
                $FailedTest.AutoFixResult = "Restarted localllm-litellm container"
            }
            "Open WebUI" {
                docker restart localllm-webui
                Start-Sleep -Seconds 5
                $FailedTest.AutoFixResult = "Restarted localllm-webui container"
            }
            "Model Loaded" {
                docker exec localllm-ollama ollama pull llama3
                $FailedTest.AutoFixResult = "Pulled llama3 model"
            }
            default {
                $FailedTest.AutoFixResult = "No automated fix defined"
            }
        }
    } catch {
        $FailedTest.AutoFixResult = "Auto-fix failed: $_"
    }
}

function Show-HealthReport {
    [CmdletBinding()]
    param($Results)
    
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "               Health Check Report                " -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "==================================================`n" -ForegroundColor Cyan
    
    $tableData = @()
    foreach ($r in $Results) {
        $icon = if ($r.Status -eq "Pass") { "✅" } elseif ($r.Status -eq "Warning") { "⚠️" } else { "❌" }
        $tableData += [PSCustomObject]@{
            Status = "$icon $($r.Status)"
            Component = $r.Name
            Details = $r.Message
            AutoFix = if ($r.AutoFixAttempted) { $r.AutoFixResult } else { "N/A" }
        }
    }
    
    $tableData | Format-Table -AutoSize
}

function Invoke-HealthCheck {
    [CmdletBinding()]
    param()
    
    try {
        $results = @()
        $results += Test-DockerRunning
        
        # If docker isn't running, auto-fix it immediately before proceeding
        $dockerCheck = $results[0]
        if ($dockerCheck.Status -ne "Pass" -and $dockerCheck.AutoFixAvailable) {
            Repair-Service -FailedTest $dockerCheck
            # Re-test docker
            $dockerCheck2 = Test-DockerRunning
            $dockerCheck2.AutoFixAttempted = $true
            $dockerCheck2.AutoFixResult = $dockerCheck.AutoFixResult
            $results[0] = $dockerCheck2
        }
        
        $results += Test-ContainerHealth
        $results += Test-OllamaAPI
        $results += Test-LiteLLMAPI
        $results += Test-OpenWebUI
        $results += Test-ModelLoaded
        $results += Test-CloudFallback
        $results += Test-DiskSpace
        $results += Test-GPUAccess
        
        foreach ($r in $results) {
            if (($r.Status -eq "Fail" -or $r.Status -eq "Warning") -and $r.AutoFixAvailable -and -not $r.AutoFixAttempted) {
                Repair-Service -FailedTest $r
            }
        }
        
        Show-HealthReport -Results $results
        return $results
    } catch {
        Write-LogMessage "Health check execution failed: $_" -Level Error
        return @()
    }
}
