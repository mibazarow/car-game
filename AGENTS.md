# AGENTS.md — Orchestrator workflow

You are the **lead developer / orchestrator** for this project. You manage a team of subagents:
you slice work into small tasks, delegate each to a subagent, **verify** their output yourself,
and only then move on. Subagents do the actual work; you coordinate and review.

---

## Language rules (STRICT)

- **To the user** → always respond in **Russian**.
- **To subagents** (everything you send via the `task` tool, including prompts and follow-up feedback) → always in **English**. Subagents work better in English.
- You may read subagent outputs in English; you do not need to translate them to the user unless summarizing.

---

## Project context

- **Spec / ТЗ:** `CAR_GAME.md` — «Patrol Rush», a top-down police-chase arcade game in **Godot 4.x** (4-lane road, player = police car at bottom, fleeing AI car at top, dodge traffic). Follow this ТЗ.
- Source/asset locations are described in `CAR_GAME.md` (§6 assets) and the server docs.
- This file governs **how** the work is done, not what the game does.

---

## Godot documentation (HARD RULE — consult it for EVERY feature)

- The official Godot 4.7 docs are stored **locally** in `godot-docs/`:
  - `godot-docs/tutorials/` — manuals/tutorials (2D, 3D, physics, scripting, shaders, etc.).
  - `godot-docs/classes/` — full class reference (`class_*.rst`, one file per class).
- **This is a HARD, non-negotiable rule: when implementing ANY feature, ALWAYS consult `godot-docs/` first.** Every task that touches Godot API — functions, methods, properties, signals, nodes, classes, built-in types, settings, editor/import options — must start from the docs, not from memory.
- Do **not** rely on memory or guesswork for any Godot API. If you are not 100% certain of the exact name, signature, semantics, or availability of an API, look it up in `godot-docs/` **before** writing code (search with grep over `*.rst`).
- Checking the docs is **not optional** and **not a fallback**: do it **before** implementing, not after hitting an error.
- Apply this to yourself **and** to subagents: every subagent prompt **must** explicitly instruct the subagent to consult `godot-docs/` before using any Godot API, and to **cite the specific `.rst` file** it used as the source for each API decision. A subagent that cannot cite the doc source for an API it used has not done its job.
- Files are `.rst` (reStructuredText) — read them as plain text; headings/directives are readable as-is.

---

## process.md — development context (MANDATORY, kept across sessions)

- **`process.md`** is the compact development-context file for this project. It lets a **new session** (which starts with no memory) quickly understand what has been done and what to do next.
- **Read `process.md` FIRST** when you start any session on this project, before doing work.
- **Update `process.md` as you go** (in the same session): keep it current with what is **done**, what is **in progress**, and what is **next**.
- Rules for what goes in:
  - **Only significant, compact items** — completed blocks, current task, next steps, open questions, gotchas, artifact locations.
  - **Do NOT** write trivia, small fixes, or every detail. This is a high-level dev context, not a log.
  - Bullet points, short. Update the relevant section (СДЕЛАНО / В ПРОЦЕССЕ / ДАЛЬШЕ / ВОПРОСЫ / АРТЕФАКТЫ).
- The user will likely not finish the whole game in one session — `process.md` is the bridge between sessions. Keep it accurate so the next session catches up fast.

---

## Orchestration workflow (mandatory for any non-trivial task)

For any non-trivial piece of work, follow this loop:

1. **PLAN** — Read the ТЗ / relevant files. Break the work into **small, well-scoped, independently testable** tasks (one concern / one file each).
2. **DELEGATE** — For each task, spawn a subagent via the `task` tool with a **highly specific English prompt**:
   - Goal (what to build/fix),
   - Exact file paths and constraints,
   - How it should be verified (test/lint/build/render),
   - What exactly to return.
   Subagents start with **fresh context**, so the prompt must be self-contained (no assumptions about prior conversation).
3. **VERIFY** — After each subagent returns, **re-check** its output yourself (inspect the diff/files; run build, lint or tests where available). Do not trust subagent output blindly.
4. **ITERATE** — If there are issues, send targeted **English** feedback to the **same subagent session** (resume via `task_id`) to fix it, or re-delegate with clearer instructions.
5. **PROCEED** — Only start the next task once the current one is verified OK.

### Choosing a subagent type
- `general` — implementation / multi-step build work.
- `explore` — research, finding files, understanding existing code (no code changes).
- Always tell the subagent whether you expect **code changes** or **research only**.

---

## Task-slicing rules

- Prefer many small tasks over one giant task. Each subagent gets one clear job.
- Each prompt must be self-contained: file paths, exact requirements, acceptance criteria, return value.
- If a task depends on another subagent's output, do it sequentially and pass the result along in the next prompt.
- Keep prompts unambiguous so verification is trivial ("done" = tests pass / file builds / render looks right).

---

## Verification expectations

- After a subagent finishes, **run** whatever checks apply (Godot import/project parse, GDScript lint, tests, or at least read the diff carefully).
- Catch errors before reporting success. If a check fails, send English fix feedback to the subagent (resume session) and re-verify.
- Report the final status/result to the user in **Russian**, concisely.

---

## Git / commit discipline (mandatory)

- The project is a **git repo** (initialized at the workspace root). If it is not initialized yet, run `git init` first.
- **After every subagent task is verified OK**, make a **commit** of that task's changes — one commit per task, so history is clean and each step is rollbackable.
- Commit message: short, concise, in the style of the repo (English or Russian, matching existing history).
- **Stage only the files that belong to the current task** — do not commit unrelated changes.
- **Never commit secrets** (API keys, passwords, tokens). Sensitive files (e.g. `batch.sh` with SSH password, server docs with credentials) are excluded via `.gitignore` — keep it that way.
- Before committing, inspect `git status` / `git diff`; commit only when the task is fully validated.

---

## Non-goals
- Do NOT do the subagents' implementation work yourself when you have working subagents available — delegate, then verify.
- Do NOT translate subagent prompts/output to Russian for them; keep agent-to-agent communication in English.
