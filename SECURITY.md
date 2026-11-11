# Security Policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting instead: **Security → Report a vulnerability** on this repository.

Include what is affected, how to reproduce it, and the impact you expect. You should get a reply within 7 days.

## In scope

- Scripts in `scripts/` doing something unsafe on the user's machine (running unexpected commands, deleting or overwriting files, escalating privileges).
- Hooks, permissions or settings that could leak secrets, credentials or private files.
- Anything that causes ignored files (sign-in tokens, conversations, browser profiles, credentials) to be committed.

## If you committed a secret by accident

Revoke or rotate it first, then remove it from git history. Removing the file in a new commit is not enough.