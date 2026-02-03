# Ralph Demo Application

A simple PowerShell calculator for demonstrating Ralph-Gastown integration.

## Usage

```powershell
.\ralph-demo.ps1 -Operation add -A 5 -B 3        # Returns: 8
.\ralph-demo.ps1 -Operation subtract -A 10 -B 4  # Returns: 6
.\ralph-demo.ps1 -Operation multiply -A 4 -B 5   # Returns: 20
.\ralph-demo.ps1 -Operation divide -A 10 -B 2    # Returns: 5
```

## Testing

```powershell
.\test.ps1
```

## Ralph Integration

This app demonstrates:
- Build verification (module loads)
- Unit tests (test.ps1)
- Functional tests (actual calculations)
