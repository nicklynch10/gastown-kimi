#!/usr/bin/env pwsh
# Simple bd (beads-cli) wrapper that uses gt bead commands
# This allows Ralph scripts to work without the separate beads-cli

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

# Forward all commands to gt bead
& gt bead @Arguments
