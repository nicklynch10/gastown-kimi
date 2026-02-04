# Ralph Bead Schema

This document defines the structure of Ralph beads.

## Overview

A **bead** represents a unit of work with a clear Definition of Done (DoD). Beads are stored as JSON files.

## Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Ralph Bead",
  "type": "object",
  "required": ["intent", "dod"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique identifier for the bead"
    },
    "title": {
      "type": "string",
      "description": "Human-readable title"
    },
    "intent": {
      "type": "string",
      "description": "What needs to be accomplished"
    },
    "type": {
      "type": "string",
      "enum": ["task", "feature", "bugfix", "gate"],
      "description": "Type of bead"
    },
    "priority": {
      "type": "integer",
      "minimum": 0,
      "maximum": 5,
      "description": "Priority level (0=highest, 5=lowest)"
    },
    "lane": {
      "type": "string",
      "enum": ["fast", "feature", "maintenance", "experimental"],
      "description": "Workflow lane"
    },
    "dod": {
      "type": "object",
      "required": ["verifiers"],
      "properties": {
        "verifiers": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/verifier"
          }
        },
        "evidence_required": {
          "type": "boolean",
          "description": "Whether evidence must be attached"
        }
      }
    },
    "constraints": {
      "type": "object",
      "properties": {
        "max_iterations": {
          "type": "integer",
          "minimum": 1,
          "description": "Maximum Ralph retry iterations"
        },
        "time_budget_minutes": {
          "type": "integer",
          "description": "Time budget for completion"
        },
        "deadline": {
          "type": "string",
          "format": "date-time",
          "description": "ISO 8601 deadline"
        }
      }
    },
    "ralph_meta": {
      "type": "object",
      "description": "Internal Ralph tracking data",
      "properties": {
        "attempt_count": {
          "type": "integer"
        },
        "executor_version": {
          "type": "string"
        },
        "retry_backoff_seconds": {
          "type": "integer"
        },
        "last_attempt": {
          "type": "string",
          "format": "date-time"
        },
        "verifier_results": {
          "type": "array"
        }
      }
    },
    "status": {
      "type": "string",
      "enum": ["pending", "in_progress", "completed", "failed", "blocked"],
      "description": "Current status"
    }
  },
  "definitions": {
    "verifier": {
      "type": "object",
      "required": ["name", "command"],
      "properties": {
        "name": {
          "type": "string",
          "description": "Human-readable verifier name"
        },
        "command": {
          "type": "string",
          "description": "Command to execute"
        },
        "expect": {
          "type": "object",
          "properties": {
            "exit_code": {
              "type": "integer",
              "description": "Expected exit code (default: 0)"
            },
            "stdout_contains": {
              "type": "string",
              "description": "String that must appear in stdout"
            },
            "stderr_contains": {
              "type": "string",
              "description": "String that must appear in stderr"
            }
          }
        },
        "timeout_seconds": {
          "type": "integer",
          "minimum": 1,
          "description": "Timeout in seconds (default: 300)"
        },
        "on_failure": {
          "type": "string",
          "enum": ["stop", "continue"],
          "description": "Action on failure (default: stop)"
        }
      }
    }
  }
}
```

## Example Beads

### Simple Task Bead

```json
{
  "id": "gt-feature-login-001",
  "title": "Implement user login",
  "intent": "Create a login form that authenticates users against the database",
  "type": "feature",
  "priority": 1,
  "lane": "feature",
  "dod": {
    "verifiers": [
      {
        "name": "Build succeeds",
        "command": "npm run build",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 120
      },
      {
        "name": "Tests pass",
        "command": "npm test -- --testPathPattern=login",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 60
      }
    ],
    "evidence_required": true
  },
  "constraints": {
    "max_iterations": 5,
    "time_budget_minutes": 60
  }
}
```

### Gate Bead

```json
{
  "id": "gt-gate-smoke-001",
  "title": "[GATE] Smoke tests",
  "intent": "Ensure basic functionality works before proceeding",
  "type": "gate",
  "priority": 0,
  "dod": {
    "verifiers": [
      {
        "name": "Application starts",
        "command": "npm start & sleep 5 && curl http://localhost:3000/health",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 30
      }
    ]
  }
}
```

### Bead with Multiple Verifiers

```json
{
  "id": "gt-refactor-auth-001",
  "title": "Refactor authentication module",
  "intent": "Refactor auth module to use new JWT library while maintaining backward compatibility",
  "type": "task",
  "priority": 2,
  "dod": {
    "verifiers": [
      {
        "name": "Lint passes",
        "command": "npm run lint",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 60
      },
      {
        "name": "Type check passes",
        "command": "npx tsc --noEmit",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 60,
        "on_failure": "continue"
      },
      {
        "name": "Unit tests pass",
        "command": "npm test -- --testPathPattern=auth",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 120
      },
      {
        "name": "Integration tests pass",
        "command": "npm run test:integration",
        "expect": { "exit_code": 0 },
        "timeout_seconds": 300
      }
    ]
  },
  "constraints": {
    "max_iterations": 10,
    "time_budget_minutes": 120
  }
}
```

## Field Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `intent` | string | Clear description of what needs to be done |
| `dod` | object | Definition of Done with verifiers |
| `dod.verifiers` | array | List of verification commands |

### Verifier Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | Human-readable name |
| `command` | string | required | Command to execute |
| `expect.exit_code` | integer | 0 | Expected exit code |
| `expect.stdout_contains` | string | null | Required string in stdout |
| `expect.stderr_contains` | string | null | Required string in stderr |
| `timeout_seconds` | integer | 300 | Timeout in seconds |
| `on_failure` | string | "stop" | "stop" or "continue" |

### Constraint Fields

| Field | Type | Description |
|-------|------|-------------|
| `max_iterations` | integer | Max Ralph retry attempts |
| `time_budget_minutes` | integer | Time limit for completion |
| `deadline` | string | ISO 8601 deadline timestamp |

## Validation

Validate a bead against the schema:

```powershell
# Using the standalone executor (validates automatically)
.\scripts\ralph\ralph-executor-standalone.ps1 -BeadFile my-bead.json -Standalone

# Manual validation
$bead = Get-Content my-bead.json | ConvertFrom-Json
if (-not $bead.intent) { throw "Missing intent" }
if (-not $bead.dod.verifiers) { throw "Missing verifiers" }
Write-Host "Bead is valid"
```

## Storage Locations

| Mode | Location | Example |
|------|----------|---------|
| Full (with gt/bd) | Managed by bd CLI | `bd show gt-abc-123` |
| Standalone | `.ralph/beads/*.json` | `.ralph/beads/my-bead.json` |
| Active | `.beads/active/` | `.beads/active/gt-*.json` |
| Completed | `.beads/completed/` | `.beads/completed/gt-*.json` |

## See Also

- `RALPH_INTEGRATION.md` - Integration guide
- `QUICKSTART.md` - Getting started
- `.beads/schemas/ralph-bead.schema.json` - JSON Schema file
