---
name: notes-vault-archiver
description: Save project findings, architecture notes, investigations, and reusable documentation into the global Notes vault at ~/Developer/ghq/github.com/upft-kengotate/Notes, routing content to the right folder and defaulting project-specific notes to 03.Projects.
---

# Notes Vault Archiver

Use this skill when the user wants findings, design notes, investigation results, operational know-how, or other documentation saved **outside the current repository** into the user's global Notes vault.

## Notes Vault Root

All output for this skill goes under:

`~/Developer/ghq/github.com/upft-kengotate/Notes`

## Primary Goal

Collect and preserve useful engineering knowledge in a consistent place so it can be reused across many repositories on this PC.

## Default Routing Policy

Follow these routing rules in order.

### 1. Project-specific content

If the note is tied to a specific repository, feature, issue, incident, bug investigation, implementation change, or operational task for a single project, save it under:

`~/Developer/ghq/github.com/upft-kengotate/Notes/03.Projects/<project-folder>/`

This is the default destination for most software work.

Examples:

- architecture summaries for a repo
- print/debug investigations
- release notes for one app
- implementation memos for a feature branch
- test findings for a project

### 2. Reusable technical references

If the note is broadly reusable and not tied to one project, save it under:

`~/Developer/ghq/github.com/upft-kengotate/Notes/02-Resources/`

Examples:

- SDK usage guides
- reusable troubleshooting steps
- language/framework references
- tool cheat sheets

### 3. Broader research

If the note compares options, explores a topic across multiple projects, or captures ongoing research, save it under:

`~/Developer/ghq/github.com/upft-kengotate/Notes/04.Research/`

Examples:

- technology comparisons
- ecosystem research
- longer-form exploratory writeups

### 4. Fallback

If nothing else fits, save it under:

`~/Developer/ghq/github.com/upft-kengotate/Notes/99.Others/`

## Project Folder Rules

When routing to `03.Projects`:

1. Check for an existing folder that clearly matches the project, issue, or topic.
2. Reuse an existing folder whenever that is the obvious destination.
3. If there is no good match, create a new folder.
4. Prefer a short, human-readable folder name that reflects the actual work item or project theme.
5. Do not force repository names if the user already has a clearer project/investigation naming style.

Because this vault is user-owned and content-aware, prioritize the **meaning of the note** over a rigid naming convention.

## File Naming Rules

Create Markdown files with descriptive names, such as:

- `architecture-summary.md`
- `print-recovery-flow.md`
- `sdk-investigation.md`
- `incident-notes.md`
- `implementation-memo.md`

Avoid vague names like `memo.md`, `notes.md`, or `temp.md` unless the user explicitly requests them.

## Note Structure

Use Markdown. Prefer this structure:

1. Title
2. Context
3. Findings / Summary
4. Key files / commands / references
5. Decisions or next steps

Use the template in `references/note-template.md` when it helps.

## Workflow

When using this skill:

1. Understand whether the content is project-specific or reusable.
2. Inspect the Notes vault only enough to choose the right destination.
3. Reuse an existing folder when appropriate; otherwise create one.
4. Write or update a Markdown document in the chosen folder.
5. Tell the user the exact saved path.

## Guardrails

- Never save these notes inside the current repository unless the user explicitly asks.
- Prefer updating an existing note if it is clearly the same ongoing topic.
- Do not overwrite existing notes blindly; read first, then append or revise intentionally.
- Keep notes concise but durable: optimize for future reuse.

## References

- Routing rules: `references/routing-rules.md`
- Note template: `references/note-template.md`
