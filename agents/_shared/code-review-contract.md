# Code Review Classification Contract

This file is the shared taxonomy for the `/code-review` skill, the `code-reviewer` agent, and the `code-reviewer-diff` agent. It contains **classification contract only** — the exclusion list, scope-guardrail thresholds and tier labels, severity tiers, verdict criteria, output template, and language-specific checks. Analysis priorities and scope-guardrail actions (parallel-group counts, abort/filter menus, two-stage review sequencing) are consumer-specific and live in each consumer's own file, not here.

Agents reference this file from `~/.claude/agents/_shared/code-review-contract.md`. Cursor deploy rewrites to `~/.cursor/agents/_shared/code-review-contract.md`.

> **Edit at `agents/_shared/code-review-contract.md` in the repo; never edit the deployed copy.**

---

## Exclusion list

Default file categories to exclude from review (drop silently; list at the end under a collapsed "Excluded files" section):

- Lock files: `*.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Pipfile.lock`, `poetry.lock`, `Gemfile.lock`, `composer.lock`, `Cargo.lock`, `go.sum`
- Auto-generated code: files containing `// Code generated`, `# Auto-generated`, `@generated`, or `DO NOT EDIT` in the first 5 lines
- Vendored dependencies: `vendor/`, `node_modules/`, `third_party/`, `external/`
- Binary files: images, fonts, compiled artifacts (detected by git's binary marker in the diff)
- Minified bundles: `*.min.js`, `*.min.css`, `*.bundle.js`
- IDE/editor config: `.idea/`, `.vscode/settings.json`, `*.swp`

---

## Scope-guardrail thresholds and tier labels

Count remaining changed files after exclusions and assign a scope tier:

- **< 5 files** — small scope
- **5–30 files** — medium scope
- **31–80 files** — large scope
- **81+ files** — very large scope

Consumer-specific actions for each tier (parallel-group counts, warnings, abort/filter menus) live in each consumer's own file.

---

## Severity tiers

| Tier | Label | Meaning |
| :----- | :----- | :----- |
| 🔴 | **Critical** | Must fix before merge — bugs, security vulnerabilities, data loss risks. |
| 🟠 | **Warning** | Should fix — performance bottlenecks, error handling gaps, fragile logic. |
| 🟡 | **Suggestion** | Consider improving — readability, naming, structure, minor optimizations. |
| 🔵 | **Info** | Observation — alternative approaches, knowledge sharing, minor style notes. |

---

## Verdict criteria

| Verdict | When to use |
|---|---|
| **APPROVE** | Zero Critical and zero Warning findings. Suggestions/Info only, or no findings at all. |
| **APPROVE WITH COMMENTS** | Zero Critical findings, but one or more Warnings exist that are low-risk or have straightforward fixes. No blocking issues. |
| **REQUEST CHANGES** | One or more Critical findings, OR multiple Warnings that together represent significant risk. Must be addressed before merge. |

The verdict is determined mechanically from the classified findings, not from subjective judgment. If in doubt between APPROVE WITH COMMENTS and REQUEST CHANGES, check whether any Warning could cause a production incident — if yes, REQUEST CHANGES.

---

## Output template

```text
# Code Review: [commit summary or PR title]

## Summary Checklist

- [ ] Correctness — Logic is sound, edge cases handled.
- [ ] Security — No vulnerabilities introduced (injection, XSS, auth bypass, secrets exposure).
- [ ] Performance — No unnecessary allocations, N+1 queries, or blocking operations.
- [ ] Error Handling — Failures are caught, logged, and surfaced appropriately.
- [ ] Readability — Code is clear, well-named, and follows project conventions.
- [ ] Testing — Changes are covered by tests, or test gaps are noted.
- [ ] Dependencies — New dependencies are justified and version-pinned.

## Detailed Findings

### [filename:line-range]

**[🔴/🟠/🟡/🔵] [Short title]**

[Explanation of the issue, why it matters, and the recommended fix.]

**Current:**
[problematic code snippet]

**Suggested:**
[improved code snippet]

---

## Cross-File Impact

[Only include if cross-file issues were found. Otherwise omit this section.]

- `callers/of/renamed_function.ts:42` — calls `oldName()` which was renamed to `newName()` in `lib/utils.ts`

---

## Verdict

**[APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES]**

[1-3 sentence rationale.]

### Excluded files

<details>
<summary>N file(s) excluded from review</summary>

- `package-lock.json` — lock file
- `src/generated/api.ts` — auto-generated

</details>
```

---

## Language-specific checks

**Python**: Mutable default arguments, bare `except:`, `from module import *` in non-`__init__` files.

**JavaScript/TypeScript**: `==` vs `===`, unhandled promise rejections, `var` instead of `const`/`let`, excessive `any` types.

**C#/.NET**: `async void` (should be `async Task`), `IDisposable` without `using`, missing null-conditional (`?.`).

**SQL**: Dynamic SQL via concatenation, missing transactions on multi-statement operations, undocumented `NOLOCK` hints, cursors where set-based logic suffices.

**PowerShell**: `Write-Host` vs `Write-Output`/`Write-Verbose`, missing `-ErrorAction`, `try/catch` without `-ErrorAction Stop`, missing parameter validation attributes.

**Dart/Flutter**: `print()` in production (use `debugPrint()`), missing `await` on `Future`-returning calls, undisposed controllers (`TextEditingController`, `AnimationController`), `setState()` after `dispose()` (guard with `mounted`), `late` variables accessed before initialization, `dynamic` where a concrete type can be inferred, missing `const` constructors on immutable widgets, deeply nested widget trees, `BuildContext` used across async gaps without `mounted` check.

**Bash/Shell**: Unquoted variables, missing `set -euo pipefail`, `eval` with user input, unchecked exit codes.

**Go**: Unchecked error returns (`val, _ := fn()`), goroutine leaks (unbuffered channels with no reader, missing context cancellation), `defer` in loops (resource accumulation), `sync.Mutex` copied by value, `interface{}` / `any` where a concrete type is known, race conditions on shared maps without `sync.Map` or mutex, `init()` functions with side effects, panics in library code (should return errors).

**Rust**: Unwrap/expect on `Result`/`Option` in non-test code (use `?` or match), `unsafe` blocks without safety comments, `clone()` on large types in hot paths, unbounded `Vec::push` in loops without `with_capacity`, `Arc<Mutex<>>` where channels would be clearer, missing `Send`/`Sync` bounds, `.unwrap()` after `.lock()` without poisoning rationale, raw pointer dereference without invariant documentation.

**Java/Kotlin**: Checked exceptions swallowed silently, `== ` on objects instead of `.equals()` (Java), mutable collections exposed from getters (return defensive copy or `Collections.unmodifiable*`), `synchronized` on non-final fields, resource leaks (streams/connections not in try-with-resources), `@SuppressWarnings` without justification, `Optional.get()` without `isPresent()` check, Kotlin `!!` (non-null assertion) outside test code, `lateinit` without initialization guarantee, data class with mutable properties.

**Ruby**: Monkey-patching core classes, `rescue Exception` (too broad, catches `SystemExit`/`SignalException`), mutable default arguments (`def foo(arr = [])`), string interpolation in logs without level guard, missing `freeze` on string constants, `eval`/`send` with user input, N+1 queries in ActiveRecord (missing `includes`/`preload`).

**C/C++**: Buffer overflows (unbounded `strcpy`/`sprintf`/`gets` — use `strncpy`/`snprintf`/`fgets`), use-after-free, double-free, null pointer dereference without check, memory leaks (malloc without corresponding free, `new` without `delete` or smart pointer), uninitialized variables, signed/unsigned comparison, integer overflow in arithmetic, `printf` format string mismatches, missing `virtual` destructor in base classes with virtual methods (C++), raw `new`/`delete` instead of `std::unique_ptr`/`std::shared_ptr` (C++), dangling references from returning reference to local (C++).
