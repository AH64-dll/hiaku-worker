---
name: orchestrate
description: Quality-gated orchestration. Splits a big task into many small tasks run by lean Haiku 5.5 (xhigh) workers in waves; the orchestrator reviews each wave against a quality bar and relaunches targeted improvement waves (default max 4) until it approves. Invoke as /orchestrate <task> (add "max N waves" to change the limit).
argument-hint: "<the big task> [max N waves]"
disable-model-invocation: true
hooks:
  PreToolUse:
    - matcher: "Agent|Task"
      hooks:
        - type: command
          command: /home/amrhares/.claude/orchestrator/hooks/pre-dispatch.sh
  PostToolUse:
    - matcher: "Agent|Task"
      hooks:
        - type: command
          command: /home/amrhares/.claude/orchestrator/hooks/post-dispatch.sh
---

# Orchestrate

You are the orchestrator, running on this session's model. Task from the user:

$ARGUMENTS

You do NOT just split work and glue the results together. You run waves of workers, REVIEW what comes back against a quality bar, and only deliver when you approve it.

Workers are the `worker` subagent (Haiku 5.5, xhigh effort). They start with an EMPTY context: no CLAUDE.md/AGENTS.md, no skills, no MCP, no history, and they cannot ask you questions. Never use another subagent type for this pipeline's work.

## What the workers can and can't do (size your fan-out by this)
- Strong at focused, well-specified, bounded jobs: extract, summarize, transform, edit one file, write one section, run one check.
- Weaker as context grows, on long multi-part or multi-file coordination, on holding many constraints at once, and on long outputs (they drift and skip things). A weak or vague brief gives weak work.
- Hard limits: 100k tokens of context (it auto-compacts there; a task that needs more than that at once fails with "Autocompact is thrashing") and 30 turns. A typical small task peaks around 10k tokens.
- So prefer MANY narrow tasks over few broad ones. Per task: one clear verb, one output file, at most ~25k tokens of input and ~5 files touched, no decisions that depend on other tasks, explicit acceptance criteria and output format.
- Fan-out rule of thumb: number of tasks ≈ total input tokens ÷ ~20-25k, per distinct part of the deliverable (estimate with `wc -c`, ~4 chars/token; don't read everything yourself). Dispatch at most ~10 per message and plan at most ~40 workers per wave; if more, rescope or merge in layers (a merge worker per group, then you). Never pull everything into one context, yours or a worker's.
- Improvement waves should be even narrower than wave 1: one cluster of defects per task.

## Protocol

**0. Limits.** Max waves = 4 total (wave 1 is the base, up to 3 improvement waves) unless the user's task text says otherwise ("max 6 waves", "waves=2", "single pass"). Tell the user the limit in your first progress line. If the whole task is trivial, just do it yourself and say so.

**1. Quality bar first.** Make the run dir `.orchestrator/<run-id>/` (short slug + timestamp) in the current project. Before dispatching anything, write `.orchestrator/<run-id>/quality.md`: concrete, checkable standards derived from the user's request: completeness/coverage, correctness against the sources, consistency across parts, requested format, nothing invented. Add a per-task `acceptance` list in `plan.json`. This is the yardstick for every review. Make criteria mechanically checkable wherever you can.

**2. Wave 1 (base work).**
- Plan: `plan.json` with tasks: `id`, `goal`, `inputs` (paths/ranges, never contents), `depends_on`, `result` path, `acceptance`, `size_estimate` (target 25-40k tokens of work at most).
- Briefs: for each task write `.orchestrator/<run-id>/w1/tasks/<id>.brief.md`, fully self-contained: goal, exact input paths/ranges, constraints and conventions (the worker knows none of this session's rules), acceptance criteria, output format, the result path `.orchestrator/<run-id>/w1/results/<id>.md`, and what to put in the short reply. Keep briefs under ~6k tokens; reference inputs by path, never paste content.
- Dispatch: Agent tool, `subagent_type: "worker"`, a short `description`, and a one-line prompt: `Read .orchestrator/<run-id>/w1/tasks/<id>.brief.md and do it.` (A hook rejects any other form.) Do not set `model`. Launch every task whose dependencies are met in parallel in one message; run dependents after their inputs exist.
- Failures: a `needs_split` reply, a failure, "Autocompact is thrashing", or a hook warning about >80k tokens means that task was too big: split it smaller (smaller input slices, a later task merges partial results from files) and retry within the same wave once.

**3. Review gate. This is a real review, not assembly.**
- Per task: open the result file itself (not just the worker's reply). Verify against the source inputs by targeted reads and sampling. Run programmatic checks wherever possible (tests, grep/wc, format or schema validators, file existence, counts). Check the worker really did what the brief asked.
- Across tasks: gaps, overlaps, contradictions, inconsistent style or terminology, anything the user asked for that no task covered.
- Write `.orchestrator/<run-id>/review-w<N>.md`: per task PASS or FAIL; for each defect the location, the evidence, and what correct looks like; then your overall verdict against `quality.md`.
- Be strict but fair: fail only real defects against the bar, not taste. Protect your own context: for big outputs review by sampling and scripts, don't reread everything blindly.

**4. Decide.**
- Meets the bar: assemble or merge the result into its real destination (not only under `.orchestrator/`), then give the user the final output and a short report: waves used, what the reviews caught and fixed, where files live. (`.orchestrator/usage.jsonl` has per-worker token usage.)
- Below the bar and waves remain: launch the next wave.

**5. Improvement wave N+1.**
- Redo ONLY the failed tasks, plus integration or fix tasks for cross-task problems. Do not redo tasks that passed; keep their results as they are.
- Each fix brief goes in `.orchestrator/<run-id>/w<N+1>/tasks/<id>.brief.md` and contains: the original goal, the path of the previous result to build on, your exact review findings for it (what is wrong, where, evidence, the fix required), what must be kept as is, and the same acceptance criteria. Results go in `w<N+1>/results/`.
- Dispatch exactly as in wave 1, then review again (step 3). Say in one line what the new wave targets.

**6. Wave cap reached without approval.** Do not ship it silently and do not take over silently. Show the user the best current version, list the unmet items from your last review, and ASK whether they want you to do the work yourself (or run more waves). Then wait for their answer.

**7. Progress.** After each wave give the user one short line: tasks launched, review verdict, next action.

## Rules
- Pass paths, not content. Never paste file contents into briefs or prompts.
- Workers write full output to result files and reply in under 500 tokens.
- Don't ask a worker to reread this skill or the plan; its brief is all it gets.
- Only the review decides quality. A worker saying "done" is not evidence.
