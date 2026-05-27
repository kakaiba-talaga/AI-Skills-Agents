# Tooling

Scripts for deploying agents and skills to harness global directories and for generating Cursor-native companions from Claude Code sources.

## Cursor transform scripts

| Script | Source | Output |
| :--- | :--- | :--- |
| `transform-cursor-ops.{ps1,sh}` | `skills/ops/SKILL.md` | `skills/ops/SKILL.cursor.md` |
| `transform-cursor-deploy.{ps1,sh}` | `skills/deploy/SKILL.md` | `skills/deploy/SKILL.cursor.md` |
| `transform-cursor-ralph-loop.{ps1,sh}` | `skills/ralph-loop/SKILL.md` | `skills/ralph-loop/SKILL.cursor.md` |

Each pair shares the same embedded Python transform body (`.ps1` writes it to a temp file; `.sh` uses a heredoc). Regenerate after editing the source `SKILL.md`:

```powershell
.\tooling\transform-cursor-ops.ps1 -Force
.\tooling\transform-cursor-deploy.ps1 -Force
.\tooling\transform-cursor-ralph-loop.ps1 -Force
```

```bash
./tooling/transform-cursor-ops.sh -f
./tooling/transform-cursor-deploy.sh -f
./tooling/transform-cursor-ralph-loop.sh -f
```

### Default behavior (drift-check)

With no flags, scripts compare the committed `SKILL.cursor.md` to what the transform would produce today:

- **In sync** — print `No drift — … is in sync.` and exit **0**.
- **Drift** — print a SHA summary (and a short unified diff) to stderr, then:
  - **Interactive TTY** — prompt to regenerate; exit **4** if declined.
  - **Non-interactive / CI** (stdin not a tty) — exit **3** without writing.

Other exit codes: **1** input error (missing source, no Python); **0** for `-WhatIf` / `--what-if` and stdout mode (`-o -`).

### CI drift gate

GitHub Actions workflow [`.github/workflows/transform-drift.yml`](../.github/workflows/transform-drift.yml) runs all three `.sh` drift-checks on pushes and PRs that touch the ops, deploy, or ralph-loop skill trees (or the transform scripts). A failing job means `SKILL.cursor.md` is out of date — run the matching transform with `-Force` / `-f` and commit the result.

Local CI-style check (non-tty, no prompt):

```bash
./tooling/transform-cursor-ops.sh </dev/null
./tooling/transform-cursor-deploy.sh </dev/null
./tooling/transform-cursor-ralph-loop.sh </dev/null
```

Any non-zero exit (expect **3** on drift) fails the check.

### Post-B1 ops hub scope (Phase B)

After ops modularization (B1), `transform-cursor-ops` drift-check compares **`skills/ops/SKILL.md` → `skills/ops/SKILL.cursor.md` only**. Phase workflow prose moved to `skills/ops/phase-*.md` companions; embedded patches whose anchors now live in those files are **intentionally skipped** on the hub pass (no `PATCH NOT FOUND` warning). Cursor-specific dispatch/TodoWrite detail for trivial runs is harness-neutral in `phase-intake.md` plus hub patches in `SKILL.cursor.md`. Phase companions receive `Bash`→`Shell`, `Agent`→`Task`, and `~/.claude/`→`~/.cursor/` rewrites at **Cursor deploy** time (`tooling/deploy.ps1` / `deploy.sh`), not via this drift gate.

## Deploy

See repository `README.md` and `docs/portability-guide.md` for `deploy.ps1` / `deploy.sh` usage.

`tooling/deploy-manifest.json` excludes build-only skill artifacts from every target: `**/SKILL.cursor.additions.md` (transform patch source). The Cursor target also excludes `**/SKILL.cursor.md` — deploy writes that content as `SKILL.md` at the destination only.
