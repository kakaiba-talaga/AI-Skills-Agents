<!-- Referenced by ~/.claude/skills/ops/SKILL.md. Keep in sync. -->

# Orchestrator Obligations

This skill is careful about what agents owe you. It is much quieter about what you owe the run. Every rule here fills one of those blanks.

## The board, and everything that is not the board

The board is `.ops-state/<run-id>-board.json`. It is ephemeral, it is yours, and it is the only place dispatch state lives.

Anything else that tracks work is not the board. A triage page, a backlog document, a status file, a spreadsheet: if the user asked for one, build it and keep it current. It is a deliverable and it matters. It is still not the board, no matter how closely it resembles one, how often it calls itself one, or how much more readable it is.

When the two disagree, the board is right about dispatch state and the artifact is right about whatever the user asked it to track. They are not two views of one thing, so nothing reconciles them and neither is derived from the other.

The way this goes wrong is quiet. An artifact that reads like a board gradually attracts the writes a board should get, and the board stops being updated without any decision to stop updating it. Nothing breaks at that moment. The run keeps dispatching, the artifact keeps looking healthy, and work is being enrolled somewhere the loop cannot see.

## Enrolling work that arrives mid-run

Work enters the board at Phase 2, built from the plan. Most work on a long interactive run does not arrive then.

There is no separate ceremony for late arrivals. A task is created and transitioned exactly like any other, in the message that spawns it. If you are about to spawn an agent for something that has no card, the card comes first, in that same message.

A board where everything is terminal does not mean the run is over. It means everything enrolled so far is done. If you are still dispatching, there is unenrolled work, and the board is the thing that is wrong.

The advisory preflights are enrolled too. A preflight, code-intel, corpus-search or docs-lookup dispatch happens after the board exists, so each gets an internal bookkeeping task like any other dispatch. Being advisory changes whether the run waits on the answer, not whether the work is on the board.

## The two windows where this does not apply

The enrolment rule holds while the board file is on disk. There are exactly two windows where it is not, and you tell them apart by looking rather than by deciding which phase you are in.

| Board file | Cleanup record | Where you are | Enrolment rule |
| :--- | :--- | :--- | :--- |
| present | either | Enrolling work | Applies |
| absent | present | After cleanup deleted the board, finishing up | Does not apply |
| absent | absent | Before the board is built, or outside a run | Does not apply |

Before the board exists, the dispatches that run are the ones that produce the plan the board is built from: the interviewer, the architect, the planner, the scoper, the critic. They cannot enrol into a board that is about to be initialised empty, and creating one early would be overwritten. That window closes when the board is created, and it is meant to close quickly.

After cleanup deletes the board, the dispatches that run are the completion menu's own. The cleanup record is still on disk at that point, which is how you know where you are. Nothing else belongs in that window.

Neither window is a licence. If you find yourself taking up new work in either one, the answer is not to dispatch unenrolled: before the board, get to the board; after it, that work belongs to a new run.

## Closing out what you enrolled

A task that went to `in_progress` is closed out when its agent returns: record `completed_at` and `duration_seconds`, then set the terminal status, in the beat that processes the return. The dispatch loop already does this for pipeline work. It is the same everywhere else, because the obligation follows the enrolment and not the phase: a preflight validation row, a status check's `work-verifier` row, a resume classification row, a trivial route's `change-analyzer` or `git-master` row, and a completion-phase row all close out the same way.

Enrolment without a close-out is a guard that never clears. Neither `pending` nor `in_progress` is terminal, and the completion phase triggers only once every task is terminal, so a single row left running holds the run open with nothing scheduled to close it. The run then strands what it produced and leaves its board on disk.

A route that ends by stopping closes its rows before it stops. That costs nothing extra: the verdict is already in hand, because a dispatch whose result the route consumes in the same turn runs in the foreground (see `dispatch-policy.md`), and a close-out is a bookkeeping write, so it may ride the very message that renders the route's output. A read-only route is where this matters most, since the row it opened would otherwise outlive the route that opened it.

What you check is what the enrolment rule checks: the board file, and whether it carries a row this turn moved to `in_progress`. If it does, that row is yours to close before the turn that stops. No claim about the route being read-only, advisory, cheap, or outside the dispatch loop moves it.

## Committing what the run produced

A task that reaches `completed` and left a diff gets committed. Nothing in this skill said so until now, which is how a run could finish with every deliverable on disk, every status terminal, and not one commit made. The completion menu then offers to merge a branch that is even with its base, open a pull request with an empty diff, or discard commits that were never written.

The obligation is the plain one. Dispatch `git-master` to commit it, and do that while the board is still on disk, so the dispatch rides a task transition like every other spawn.

### The boundary is the task reaching `completed`

A task reaches `completed` when its own agent returns having met its own criteria, so the commit covers that agent's work at that point. A later fix task commits separately, over its own diff.

This keeps the recovery path clear too. A `broken` verdict targets a task that is running, never one that is `completed`, so the task a rollback reverts has no commit of its own to fight. The rule that committed changes need explicit approval before they are reverted is unchanged and correct. It stays where it belongs, on the rarer case where a chain-level or run-level revert reaches back over tasks that did settle.

### A task with no diff is not committed

The trigger has two conditions and both are things you look at. The task is `completed`, and `git status --porcelain` restricted to that task's files comes back non-empty. A verifier task that runs a suite and changes nothing meets the first and fails the second, so it produces no commit and no empty-commit attempt.

Work that no deliverable task owns still has a row. The cleanup pass's row, the re-verification spawn's row, and a review-fix task's row are all board tasks, so the same rule reaches them with no special case. Whichever of them left a diff gets a commit.

### One task sets the scope; the diff decides the count

`git-master` splits a diff by concern, and a single task can touch configuration, logic, and tests at once. That is not a conflict, because the two rules answer different questions. The task sets which files the commit covers. `git-master` decides how many commits that set becomes.

So the obligation is that the task's diff is fully committed, not that it becomes exactly one commit. What the rule does forbid is the other direction. Do not bundle one task's diff in with another's: the board is what the run can account for, and a commit spanning two tasks belongs to neither.

### One commit dispatch at a time

Two commit dispatches on one branch collide on the index, and this skill already forbids running git operations on the same branch in parallel. Several tasks can go `completed` in a single turn, which is exactly when that would happen.

They serialize on the board rather than on a rule about turns. Process each return in arrival order, as you already do. The first commit task is created and transitioned in the message that dispatches it. Each later one is created `pending` with `blocked_by` naming the commit task ahead of it, and the dispatch scan then releases them one at a time on the ordinary check: a task is a candidate when what blocks it is terminal.

The dispatch itself is a background one. Nothing in the turn that fires it consumes its result, so it does not meet the bar for blocking, and the ordering above holds without blocking anything.

### Which files get staged

Give `git-master` the task's file list and the rule for applying it in the same brief, since it works to the lane its brief defines. The test is what git already knows about each path, never what the path looks like.

- **A file git already tracks is committed, no question asked.** `git add -u` with explicit paths stages exactly these. It needs no override flag, and it fails loudly on a path git does not track, so it cannot quietly widen.
- **A file git neither tracks nor ignores** is a new file this run created. Stage it with a plain add and an explicit path.
- **A file git does not track and does ignore** is left alone, and named in the report so the user sees what was skipped.

`git ls-files` restricted to the task's paths returns the first set. `git ls-files --others --exclude-standard` restricted the same way returns the second. Anything in the list and in neither set is the third.

Never `git add -A`, never `git add .`, and never the force flag. Force is the one flag that would stage an ignored file git does not track, which is the single case this rule exists to hold back. A staging step that reaches for it has inverted the rule, not worked around a nuisance.

**A tracked file that is also ignored is an ordinary state, not a contradiction.** A project can ignore a directory broadly and still keep particular files inside it under version control. Those files stay tracked, their changes still show up in `git status`, and they get committed like anything else. An ignore check coming back true is not a reason to skip a file. Only git not tracking it is.

**One mechanical trap travels with that state.** When the ignored thing is the directory, git refuses a plain add of any path inside it, and it refuses for a tracked file exactly as it refuses for an untracked one, naming the directory rather than the file. The staging order above is what gets past this: `git add -u` never consults ignore rules, because every path it can touch is already tracked. Reaching for force here would also work, and would destroy the guard.

**"Already tracked" is read at the moment of staging.** A file an earlier task in this run created and committed is tracked by the time a later task edits it, and that later edit is committed like any other tracked change. Whether the file predates the run does not enter into it.

The one path-shaped exception is the run's own paperwork. A planning or review artifact this run told an agent to write is not staged unless the user named it, and you know which paths those are because they are the deliverables recorded on those tasks' own rows.

### A rule about what goes in a commit is not a rule about whether to commit

This project keeps its own paperwork out of commits by default, and that rule is real. It has been read once as a reason to make no commit at all, which it never said.

Tell the two apart by what the rule constrains. A rule about the staged-file set answers "which of these files go in", and its answer can be "none of them", which still leaves a commit to make from whatever else the task touched. A rule about permission would answer "may I commit", and no rule here says that. If applying the rule you have in mind leaves you with an empty staged list and you conclude the task should not be committed, you have swapped one question for the other.

The same test catches the general case. Before a rule stops you, read it, and check that the sentence covers the thing you are about to not do rather than a neighbouring thing it could be stretched to cover. A rule you are sure exists usually does. Whether it says what you need it to say is the separate question, and it is the one that goes unasked.

### The run does not finish with an uncommitted diff

Before cleanup deletes the board, check whether the working tree still holds changes this run made. If it does, some task's diff never reached a commit, and the moment to fix it is while the board still exists: enrol a commit task, dispatch it, close it out.

After the board is gone there is no honest way to do this. That window belongs to the completion menu's own dispatches, and a commit made there would have no row to ride. So the check sits before the delete, not after it, and the menu is entitled to assume the branch it is about to merge, push, or discard actually contains the run's work.

## Verifying what an agent reports

An agent verifies its own work before claiming completion. That is its ritual and it is written down. Nothing correspondingly obliges you to check the claim before you repeat it, which means a confident wrong report becomes a confident wrong status update at no cost.

So before relaying an agent's claim as fact, check the change it asserts rather than the artifact that change would live in. Grep the file for the text it says it added, read the region it says it rewrote, read the status field on the card it says it closed. An existence check is the trap: the file is there, it is not empty, the paragraph was never added, and the check passes anyway.

One look at the asserted change, then, not a re-run of the agent's work. Some claims have no artifact to look at, a passing test being the usual one. For those the agent pastes the command it ran and the output it got, and you check that the pasted output names the criterion it is offered against. That paste is the bounded check for that class. Re-running the suite yourself is not the bar, and a claim carrying neither an inspectable change nor a pasted result has not been checked at all.

Report what you checked. "The card is out of the file" and "the agent says the card is out of the file" are different claims, and only one of them survives the file not having changed.

## Findings an agent reported and did not fix

Agents report out-of-scope work and leave it alone. That rule binds the agent. It does not bind you, and dispatching a second agent at the finding is usually the obvious move.

Every reported finding gets one of these outcomes. Repeating it to the user is not among them, and neither is intending to get to it.

| Disposition | When | Board result |
| :--- | :--- | :--- |
| Queued | The correction is truth-restoring | A task, `pending`, dependencies wired |
| Deferred | Something has to happen first | A task, `pending`, with `blocked_by` pointing at the task that trigger belongs to |
| Rejected | Examined, and it is not a defect | No card; the reason recorded in `adaptations` |
| User must choose | The resolution is not yours to pick | `blocked`, which already means paused pending user resolution |

Log the disposition in the run-level `adaptations` array with `type: finding`.

Carding a finding needs no permission. It adds work that was never in the plan, so it removes nothing and reduces no scope. The card is how the user finds out, and it costs a turn less than asking.

### Queue it, or leave it

One question: can the correction be written without anyone choosing anything?

- **Truth-restoring, so queue it.** The artifact asserts something false, and exactly one correction is right, because the facts that settle it are already established.
- **Decision-requiring, so leave it.** Resolving it means picking between alternatives that are all still defensible. Writing either one in would be you making the call.

"It requires a decision" is the most available excuse for not acting, so guard it: an unrecorded decision is a stale fact; an unmade decision is the user's. The distinction is whether the choosing has happened, not whether a choice is nominally involved. A document that lags a decision its owner already made is stale, not open.

### Deferring means naming the task you are waiting on

A `pending` card may point `blocked_by` only at another task on this board. If what you are waiting for is not a task yet, make it one and depend on that. "Until the suite is green" becomes a task that confirms the suite is green.

Never record a deferral as already-terminal. It drops out of the run's remaining work, and if it was the last one outstanding it hands the run a completion nobody earned.

## What none of this asks of you

It does not ask you to act through your own gates. A stated condition, an explicit decline, a recommendation put to the user, or a deferral on real contention are all correct turns. Naming the condition is the point. A turn that says why it is not acting has done its job; a turn that says it will act and does not is the one this file is about.
