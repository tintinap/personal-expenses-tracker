# Bug Report: dev.sh services exit immediately

## Summary
Running `mise run dev` starts both NestJS and Next.js, prints the "running" banner, then immediately shuts down both services.

## Root Cause
`scripts/dev.sh` used `wait -n $PID1 $PID2` on line 64 to block the script until a background process exits. **`wait -n` requires Bash 4.3+**, but macOS ships with **Bash 3.2**.

On Bash 3.2, `wait -n` fails with an unsupported flag error. The `|| true` suppressed the error, causing the script to immediately fall through to the end. This triggered the `EXIT` trap (`cleanup()`), which killed both background processes.

## Execution Flow
```
wait -n $API_PID $WEB_PID   # Fails silently (Bash 3.2)
|| true                      # Error suppressed → script continues
# Script ends → EXIT trap fires
cleanup()                    # Kills API_PID and WEB_PID
```

## Fix
Replaced `wait -n` with `wait` (no `-n` flag). Plain `wait` blocks until ALL background jobs finish, and is compatible with all Bash versions.

```diff
-wait -n $API_PID $WEB_PID 2>/dev/null || true
+wait $API_PID $WEB_PID 2>/dev/null || true
```

## Prevention
- Avoid Bash 4+ features (`wait -n`, associative arrays, `|&`) in scripts that must run on macOS.
- Alternatively, use `#!/usr/bin/env zsh` on macOS projects since zsh is the default shell and supports modern features.

## Files Changed
- `scripts/dev.sh` (line 64)
