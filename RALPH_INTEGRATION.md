# Ralph-Gastown Integration Guide

Detailed technical documentation for the Ralph-Gastown integration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GASTOWN CONTROL PLANE                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │  Beads  │  │  Hooks  │  │ Convoys │  │Molecules│  │  Gates  │       │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘       │
│       └─────────────┴─────────────┴─────────────┴─────────────┘         │
│                              ▲                                          │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────────┐
│                         RALPH EXECUTION TACTIC                           │
│                              │                                           │
│  ┌───────────────────────────┴──────────────────────────────┐            │
│  │                    Ralph Retry Loop                       │            │
│  │                                                           │            │
│  │   ┌──────────┐    ┌──────────┐    ┌──────────┐          │            │
│  │   │  Run DoD │───→│ Kimi Impl│───→│  Run DoD │          │            │
│  │   │Verifiers │    │  Story   │    │Verifiers │          │            │
│  │   │(fail OK) │    │          │    │(must pass)│         │            │
│  │   └────┬─────┘    └──────────┘    └────┬─────┘          │            │
│  │        │      ╲                  ╱      │               │            │
│  │        │       ╲  All Pass?    ╱       │               │            │
│  │        │        ╲            ╱         │               │            │
│  │        │         ╲  YES    ╱          │               │            │
│  │        │          ╲      ╱           │               │            │
│  │        └──────────→[DONE]←───────────┘               │            │
│  │                        │                              │            │
│  │                        │ NO                          │            │
│  │                        ▼                             │            │
│  │                   [Retry w/                             │            │
│  │                    Context]                             │            │
│  │                        │                              │            │
│  │                        └──────────────────────────────┘            │
│  │                                                           │            │
│  └───────────────────────────────────────────────────────────┘            │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

## Three-Loop System

### 1. Build Loop (molecule-ralph-work)

**Purpose:** Implement a bead with DoD enforcement

**Flow:**
1. Load bead context and validate contract
2. Set up working branch
3. Run verifiers (TDD - expecting failures)
4. Invoke Kimi with intent + constraints + verifiers
5. Kimi implements solution
6. Run verifiers again (must all pass)
7. Retry with failure context if needed
8. Attach evidence and submit

**Formula:** `.beads/formulas/molecule-ralph-work.formula.toml`

### 2. Test Loop (molecule-ralph-patrol)

**Purpose:** Continuous testing that emits failure beads

**Flow:**
1. Run test suite on schedule
2. Run Playwright browser tests
3. On failure: create P0 bug bead
4. Attach artifacts (trace, screenshot, logs)
5. Sling bug bead to worker

**Formula:** `.beads/formulas/molecule-ralph-patrol.formula.toml`

### 3. Governor Loop (ralph-governor.ps1)

**Purpose:** Enforce "no green, no features" policy

**Rules:**
- No feature beads slung while any gate is red
- Convoys pause when gates fail
- Bug beads take precedence over features
- Max restarts trigger escalation

**Script:** `scripts/ralph/ralph-governor.ps1`

## Ralph Bead Contract

### Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Ralph Bead Contract",
  "required": ["intent", "dod"],
  "properties": {
    "intent": {
      "type": "string",
      "description": "Behavior-level change description"
    },
    "dod": {
      "type": "object",
      "required": ["verifiers"],
      "properties": {
        "verifiers": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["name", "command", "expect"],
            "properties": {
              "name": { "type": "string" },
              "command": { "type": "string" },
              "expect": {
                "properties": {
                  "exit_code": { "type": "integer", "default": 0 },
                  "stdout_contains": { "type": "string" },
                  "stderr_contains": { "type": "string" }
                }
              },
              "timeout_seconds": { "type": "integer", "default": 300 },
              "on_failure": { "enum": ["stop", "continue", "retry"] }
            }
          }
        }
      }
    },
    "constraints": {
      "properties": {
        "max_iterations": { "type": "integer", "default": 10 },
        "time_budget_minutes": { "type": "integer", "default": 60 }
      }
    },
    "lane": { "enum": ["feature", "bug", "hardening", "deps", "gate", "patrol"] },
    "priority": { "type": "integer", "minimum": 0, "maximum": 4 },
    "ralph_meta": {
      "properties": {
        "attempt_count": { "type": "integer" },
        "retry_backoff_seconds": { "type": "integer", "default": 30 }
      }
    },
    "blocking": {
      "properties": {
        "is_gate": { "type": "boolean" },
        "gate_type": { "enum": ["smoke", "lint", "build", "test", "security", "custom"] }
      }
    }
  }
}
```

### Example Bead

```json
{
  "id": "gt-feature-001",
  "title": "Implement user authentication",
  "intent": "Add JWT-based authentication to the API",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "go build ./...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 60
      },
      {
        "name": "Unit tests pass",
        "command": "go test ./auth/...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 120
      },
      {
        "name": "Integration tests pass",
        "command": "go test ./tests/integration/...",
        "expect": {"exit_code": 0},
        "timeout_seconds": 300
      }
    ],
    "evidence_required": true
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 60,
    "allowed_dirs": ["internal/auth/", "api/"]
  },
  "lane": "feature",
  "priority": 2,
  "ralph_meta": {
    "attempt_count": 0,
    "retry_backoff_seconds": 30
  }
}
```

## PowerShell Scripts

### ralph-master.ps1

Main control interface. Commands:
- `init` - Initialize Ralph environment
- `status` - Show Ralph-Gastown status
- `run` - Run Ralph executor on a bead
- `patrol` - Start patrol molecule
- `govern` - Check/apply governor policies
- `watchdog` - Start watchdog monitor
- `verify` - Verify integration health
- `create-bead` - Create a new Ralph bead
- `create-gate` - Create a gate bead

### ralph-executor-simple.ps1

Core retry loop implementation:
1. Parse bead contract
2. Run verifiers
3. Invoke Kimi with context
4. Re-run verifiers
5. Retry until DoD satisfied or max iterations

### ralph-governor.ps1

Policy enforcement:
- Check gate status
- Block features when gates red
- Enforce convoy policies
- Escalate on max restarts

### ralph-watchdog.ps1

Always-on monitoring:
- Scan hooks for stale work
- Nudge polite agents
- Restart stuck workers
- Escalate persistent failures

## Windows-Native Design

### Why PowerShell?

- **Native Windows support** - No WSL required
- **Excellent process management** - For running verifiers
- **JSON handling built-in** - For bead manipulation
- **Cross-platform** - PowerShell Core on Linux/Mac

### Compatibility

| Feature | PowerShell 5.1 | PowerShell 7 |
|---------|----------------|--------------|
| Script parsing | ✅ | ✅ |
| Execution | ✅ | ✅ |
| `??` operator | ❌ | ✅ (avoided in scripts) |

### Avoided PS7-Only Features

Scripts avoid:
- `??` null coalescing operator
- `??=` null coalescing assignment
- `?.` null conditional member access

Instead use:
```powershell
# Instead of: $timeout = $verifier.timeout ?? 300
$timeout = if ($verifier.timeout) { $verifier.timeout } else { 300 }
```

## Integration with Gastown Workflows

### Standard Workflow

```powershell
# 1. Create convoy
gt convoy create "Feature X" --human

# 2. Create gate
bd create --title "[GATE] Tests pass" --type gate
gt convoy add convoy-xyz gt-gate-001

# 3. Create feature bead
bd create --title "Implement feature" --type task
# ... add Ralph contract ...

# 4. Sling to worker
gt sling gt-abc12 myproject
# Auto-applies molecule-ralph-work

# 5. Monitor
.\scripts\ralph\ralph-master.ps1 -Command govern
```

### Patrol Integration

```powershell
# Start patrol as continuous wisp
gt sling molecule-ralph-patrol myproject

# Patrol will:
# - Run tests every N minutes
# - Create P0 bug beads on failure
# - Attach screenshots/traces
```

## Testing

### Unit Tests

```powershell
# Run Pester tests
Invoke-Pester -Path tests/ralph/
```

### Integration Test

```powershell
# Run demo application
cd examples/ralph-demo
.\test.ps1
```

### Manual Testing

```powershell
# Test each component
.\scripts\ralph\ralph-master.ps1 -Command help
.\scripts\ralph\ralph-governor.ps1 -Action check
.\scripts\ralph\ralph-watchdog.ps1 -RunOnce
.\scripts\ralph\ralph-executor-simple.ps1 -BeadId test -DryRun
```

## Troubleshooting

### Scripts Won't Parse

Check for PS7-only syntax:
```powershell
$script = Get-Content "scripts/ralph/script.ps1" -Raw
# Should not contain: ??, ??=, ?.
```

### Verifiers Timeout

Increase timeout in bead:
```json
{"timeout_seconds": 600}
```

### Kimi Not Responding

Check session:
```powershell
kimi --list-sessions
$env:KIMI_SESSION_ID
```

## References

- [Gastown](https://github.com/steveyegge/gastown)
- [Ralph Pattern](https://github.com/snarktank/ralph)
- [Ralph-Kimi](https://github.com/nicklynch10/ralph-kimi)
- [Kimi Code CLI](https://www.kimi.com/code)
