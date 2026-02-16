# Git Workflow — Checkpoint Protocol

## Quick Reference

Say **"Please commit everything"** and the assistant will run the full
hardened checkpoint below automatically.

Say **"Where are we?"** to get a status summary from `claude.md` and `status.html`.

---

## Checkpoint Steps

### 1. Pre-flight
```
git status
```
Review staged/unstaged changes and untracked files.

### 2. Secret Scan (CRITICAL — runs before every commit)
Scan the workspace for:
- `.env` / `.env.*` files
- Private key blocks (`BEGIN.*PRIVATE`)
- Files matching `*.key`, `*.pem`, `*.p12`, `*.pfx`
- Strings matching `api_key`, `secret`, `password`, `token`, `credential`
- OAuth secrets, cloud credentials, database passwords

**If anything suspicious is found:**
- STOP — do not commit
- Warn user with file list
- Recommend `.gitignore` updates
- Require explicit user confirmation before proceeding

### 3. Stage Files
```
git add <specific files>
```
- Prefer explicit file paths over `git add -A`
- Never stage `.env`, credential files, or large binaries

### 4. Commit
```
git commit -m "chore(checkpoint): <description of changes>"
```

#### Commit Message Format
```
type(scope): short description

Optional body with details.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`
**Scopes:** `checkpoint`, `vehicle`, `ui`, `fish`, `economy`, `audio`, `dive`, etc.

### 5. Push
Push only if ALL conditions are met:
- Remote `origin` exists (`git remote -v`)
- Authentication succeeds
- Branch is not `main` with `--force` (never force-push main)

```
git push -u origin <branch>
```

If push fails, print exact next steps (auth setup, remote add, etc.).
Never claim push success without verifying output.

---

## Safety Rules

1. **Never rewrite history** on shared branches
2. **Never force-push** to `main`
3. **Never skip hooks** (`--no-verify`)
4. **Never commit secrets** — always scan first
5. **Never use `git add -A`** — stage specific files
6. **Always create NEW commits** — don't amend unless explicitly asked
7. **Secret scan is mandatory** — no exceptions

---

## .gitignore Coverage

The `.gitignore` must always ignore:
- `.env`, `.env.*` — environment secrets
- `*.key`, `*.pem`, `*.p12`, `*.pfx` — certificates and keys
- `.godot/` — engine cache (large, generated)
- `*.import` — Godot import cache
- `build/`, `dist/`, `export/` — build outputs
- `node_modules/` — JS dependencies (if any tooling)
- OS files: `.DS_Store`, `Thumbs.db`, `desktop.ini`
- IDE: `.vscode/`, `*.code-workspace`
