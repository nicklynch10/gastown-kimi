#!/usr/bin/env pwsh
param(
    [Parameter()]
    [string]$Operation = "add",
    
    [Parameter()]
    [double]$A = 0,
    
    [Parameter()]
    [double]$B = 0
)

Import-Module "$PSScriptRoot/Calculator.psm1" -Force

try {
    $result = switch ($Operation) {
        "add" { Add-Numbers -a $A -b $B }
        "subtract" { Subtract-Numbers -a $A -b $B }
        "multiply" { Multiply-Numbers -a $A -b $B }
        "divide" { Divide-Numbers -a $A -b $B }
        default { throw "Unknown operation: $Operation" }
    }
    
    Write-Output $result
    exit 0
} catch {
    Write-Error $_
    exit 1
}
