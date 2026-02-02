# Kimi K2.5 Integration for Gas Town

This document describes the Kimi Code CLI (K2.5) integration with Gas Town.

## Overview

Kimi Code CLI is now fully supported as a built-in agent preset in Gas Town. This integration allows you to use Kimi K2.5 as your AI coding agent alongside or instead of Claude, Gemini, Codex, and other supported agents.

## Features

- **Full Agent Support**: Kimi is available as a built-in preset (`kimi`) alongside other agents
- **Session Management**: Supports session resumption via `--continue` flag
- **YOLO Mode**: Autonomous operation with `--yolo` flag for approval-free execution
- **Hook Support**: Uses `.kimi/settings.json` for configuration
- **Multi-Role Support**: Can be used for mayor, witness, refinery, polecat, and crew roles

## Configuration

### Setting Kimi as Default Agent

```bash
# Set Kimi as the default agent for your town
gt config default-agent kimi
```

### Per-Rig Configuration

In `settings/config.json` at the rig level:

```json
{
  "type": "rig-settings",
  "version": 1,
  "agent": "kimi"
}
```

### Per-Role Configuration

You can use different agents for different roles:

```json
{
  "type": "town-settings",
  "version": 1,
  "default_agent": "claude",
  "role_agents": {
    "mayor": "kimi",
    "witness": "kimi",
    "polecat": "kimi"
  }
}
```

## Agent Preset Details

The Kimi agent preset is configured as follows:

```go
AgentKimi: {
    Name:                AgentKimi,
    Command:             "kimi",
    Args:                []string{"--yolo"},     // YOLO mode for autonomous operation
    ProcessNames:        []string{"kimi"},       // Process detection
    SessionIDEnv:        "KIMI_SESSION_ID",      // Session tracking
    ResumeFlag:          "--continue",           // Session resumption
    ResumeStyle:         "flag",
    SupportsHooks:       true,                   // Hooks via .kimi/settings.json
    SupportsForkSession: false,
    NonInteractive:      nil,                    // Native non-interactive
}
```

## Command Reference

### Starting a Kimi Session

```bash
# Start the Mayor with Kimi
gt mayor attach

# Sling work to a Kimi-powered polecat
gt sling gt-abc12 myproject --agent kimi

# Start a crew member with Kimi
gt crew add myname --rig myproject --agent kimi
```

### Session Management

```bash
# Continue the most recent session
kimi --continue

# Switch to a specific session
kimi --session abc123

# List sessions (from within Kimi)
/sessions
```

## Hook Configuration

Kimi supports hooks via `.kimi/settings.json`. Gas Town will automatically configure hooks when using Kimi as the agent.

### Hook Directory Structure

```
<worktree>/
  .kimi/
    settings.json    # Kimi configuration and hooks
```

## Role Instructions

Kimi uses `AGENTS.md` for role instructions (similar to Codex and OpenCode). When setting up a new rig with Kimi, ensure you have an `AGENTS.md` file in your project root.

### Example AGENTS.md

```markdown
# Agent Instructions

You are working on a Gas Town managed project.

## Role
You are a [polecat/witness/mayor/crew] agent responsible for [description].

## Commands
- Check mail: `gt mail check --inject`
- Report status: `gt prime`
- Complete work: `gt done`
```

## Environment Variables

Kimi sets the following environment variables:

- `KIMI_SESSION_ID`: Current session ID for resumption
- `KIMI_CONFIG_DIR`: Configuration directory

Gas Town automatically detects and uses these for session management.

## Differences from Other Agents

| Feature | Claude | Kimi | Codex |
|---------|--------|------|-------|
| YOLO Flag | `--dangerously-skip-permissions` | `--yolo` | `--yolo` |
| Resume | `--resume <id>` | `--continue` | `resume <id>` |
| Hooks | `.claude/settings.json` | `.kimi/settings.json` | Not supported |
| Instructions | `CLAUDE.md` | `AGENTS.md` | `AGENTS.md` |
| Process Name | `node` | `kimi` | `codex` |

## Troubleshooting

### Kimi Not Found

```bash
# Verify kimi is installed and in PATH
which kimi
kimi --version
```

### Session Not Resuming

```bash
# Check if KIMI_SESSION_ID is set
echo $KIMI_SESSION_ID

# List available sessions
kimi --list-sessions
```

### Hook Issues

```bash
# Verify hooks are installed
gt hooks

# Check .kimi/settings.json exists
cat .kimi/settings.json
```

## Testing

Run the Kimi-specific tests:

```bash
cd internal/config
go test -v -run "Kimi"
```

## Implementation Details

The Kimi integration includes:

1. **Agent Preset** (`internal/config/agents.go`):
   - `AgentKimi` constant
   - `AgentKimi` entry in `builtinPresets`

2. **Runtime Configuration** (`internal/config/types.go`):
   - Provider support: `kimi`
   - Default args: `["--yolo"]`
   - Hooks directory: `.kimi`
   - Session ID env: `KIMI_SESSION_ID`
   - Resume flag: `--continue`

3. **Tests** (`internal/config/agents_test.go`):
   - `TestKimiAgentPreset`
   - `TestKimiProviderDefaults`
   - `TestKimiRuntimeConfigFromPreset`
   - `TestKimiBuildResumeCommand`

4. **Documentation**:
   - Updated README.md with Kimi references
   - This integration guide

## Migration from Other Agents

To migrate from Claude to Kimi:

```bash
# 1. Set Kimi as default
gt config default-agent kimi

# 2. Update existing roles (optional)
gt config agent set claude-kimi "kimi --yolo"

# 3. Restart agents
gt mayor detach
gt mayor attach
```

## Support

For Kimi-specific issues:
- Kimi Code CLI documentation: https://www.kimi.com/code/docs
- Gas Town issues: https://github.com/steveyegge/gastown/issues

## Changelog

### Initial Integration
- Added `AgentKimi` preset
- Full session management support
- Hook system integration
- Complete test coverage
