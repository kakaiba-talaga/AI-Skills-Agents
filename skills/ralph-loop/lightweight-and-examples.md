<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Lightweight Mode & Usage Examples

Low-frequency reference bundled into one Read. Triggers: `--lightweight` flag present, or the user asks for example invocations of `/ralph-loop`.

## Lightweight Mode

Lightweight mode (`--lightweight`) is a stripped-down single-pass workflow for trivial fixes where the full 6-stage loop is unnecessary. It runs Execute + Verify only -- no Frame, Plan, Reflect, or Cleanup.

**When to use:** Typo fixes, one-line config changes, adding a missing import, renaming a variable, small self-contained bug fixes where the problem and solution are both obvious.

**When NOT to use:** Anything that benefits from iteration, needs metric tracking, requires multiple attempts, or involves more than ~3 files. If you're unsure, use the full loop -- lightweight mode has no path back to multi-iteration if the fix turns out to be harder than expected.

**Incompatibilities:** `--lightweight` cannot be combined with `--template` (templates require the full stage pipeline) or `--headless` (headless requires structured verification). Error if either is provided alongside `--lightweight`.

**Workflow:**

1. Initialize state with `lightweight_mode: true`, `deslop_enabled: false`, `iteration: 1`.
2. **Execute** the fix directly. No framing or planning -- proceed based on the task description.
3. **Verify** the fix: run relevant tests, build, or lint checks. If the task description implies a specific check, run it. Otherwise, use the project's default verification (test suite, build command).
4. **Result:**
   - If Verify passes: set `status: done`, persist state, report success. One iteration, done.
   - If Verify fails: report the failure and ask the user how to proceed. Options:
     - a) Retry in lightweight mode (stay lightweight, attempt the fix again -- max 2 retries)
     - b) Upgrade to full loop (convert to `lightweight_mode: false`, `deslop_enabled: true`, start a full iteration from Frame with the failure context carried forward in `context.learnings`)
     - c) Pause / abandon

**State persistence:** Lightweight mode still writes a state JSON file for consistency (resume, status, list all work). The state uses `current_stage: Execute | Verify` only. `iteration` stays at 1 unless the user upgrades to full loop.

**Badge:** Still uses **`Ralph Loop`** badge but appends "(lightweight)" -- e.g., **`Ralph Loop`** (lightweight) -- Execute.

**Checklist (lightweight):**

```text
**`Ralph Loop`** (lightweight) Iteration 1 -- Execute

Ralph Wiggum Loop Progress (lightweight)

🟦 1) Execute the fix
🟦 2) Verify

(stage content here)
```

**JSONL logging:** Lightweight runs log `stage_complete` and `iteration_complete` events like the full loop. The `iteration_complete` event includes `"lightweight": true` so analytics can distinguish them.

**Upgrade path:** When upgrading from lightweight to full loop, the state transitions: `lightweight_mode` is set to `false`, `deslop_enabled` is set to `true`, `iteration` remains at 1, `current_stage` resets to `Frame`, and any failure details from the lightweight attempt are captured in `context.learnings` and `context.notes` so the full loop starts with that context.

## Usage Examples

```text
/ralph-loop improve vectorization stability and pause at 60%
/ralph-loop list
/ralph-loop list --status paused
/ralph-loop list --mode project --status active
/ralph-loop start --percent 60
/ralph-loop start --loop-mode strict --percent 60
/ralph-loop start --goal "Phase 3 smoke tests pass"
/ralph-loop start --percent 40 --goal "Baseline refactor merged"
/ralph-loop start --template accuracy-improvement --param verify_command="python tools/verify.py" --param input_dir="data/input" --percent 90
/ralph-loop start --template accuracy-improvement --param verify_command="python tools/verify.py" --param input_dir="data/input" --headless
/ralph-loop start --template refactor --param test_command="pytest" --headless --max-headless-iters 10
/ralph-loop start --template test-coverage --param test_command="pytest --cov=src --cov-report=json"
/ralph-loop start --template bug-hunt --param test_command="pytest tests/regression/" --param bug_list="login timeout, missing validation"
/ralph-loop start --template migration --param test_command="pytest" --param source_pattern="from old_auth import"
/ralph-loop start --no-deslop --percent 80 fix the login timeout bug
/ralph-loop start --template accuracy-improvement --param verify_command="python tools/verify.py" --no-deslop --percent 95
/ralph-loop start --lightweight fix the typo in README header
/ralph-loop start --lightweight add missing import for datetime in utils.py
/ralph-loop track --mode global
/ralph-loop track --mode project
/ralph-loop track --mode folder --path "data/loop-state"
/ralph-loop resume --task vec-tune-001
/ralph-loop resume --task vec-tune-001 --headless
/ralph-loop status --task vec-tune-001
/ralph-loop pause --task vec-tune-001 --reason "Need larger dataset"
/ralph-loop complete --task vec-tune-001
/ralph-loop rollback --to-iter 7 --task per-element-accuracy-80
```
