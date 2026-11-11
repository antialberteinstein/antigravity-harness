# Contributing

This is a personal Antigravity harness, but issues and small pull requests are welcome.

## Before opening an issue

- Run `bash ~/.gemini/scripts/setup.sh -n` and include its output.
- Remove tokens, API keys and personal paths from anything you paste.

## Pull requests

- Keep each PR to one change, and explain why it is needed.
- Scripts must run on bash 3.2 (macOS default): no `declare -A`, `mapfile`, `readlink -f` or GNU-only flags.
- Scripts must not run `sudo` or install anything without an explicit flag.
- Run the offline tests and make sure they pass:

  ```bash
  bash scripts/setup.d/test.sh
  ```

- Never commit secrets, sign-in tokens, `antigravity-cli/settings.json`, or anything the allowlist `.gitignore` keeps out. If you add a new tracked file, add it to `.gitignore` explicitly.
- Write code, comments, commit messages and docs in English or Vietnamese.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).