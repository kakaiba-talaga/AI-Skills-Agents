<!-- Referenced by ~/.claude/skills/ralph-loop/SKILL.md. Keep in sync. -->
# Usage examples

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
