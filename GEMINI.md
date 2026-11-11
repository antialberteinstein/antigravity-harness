## Rules

- Don't include "Co-Authored-By", "Generated with …" or any other AI attribution lines in commit messages or pull requests.
- At the start of any task that creates or changes code, activate the `karpathy-guidelines` skill once.
- Before reporting a coding task as done, run the project's tests and show the result. If no tests cover the change, write them first.
- When you create a chart, image or report that I should look at, run `show <file>` once. To check a chart yourself, view the image file.
- Before adding or changing a CI workflow that runs end-to-end tests, stop and ask me first, even if I asked for it. Explain that e2e runs are heavy and can use up GitHub Actions minutes and add charges to my account, then wait for my yes.

## Tools

- Available and authenticated: `gh`, `hf`, `kaggle`, `uv`. Use these CLIs for GitHub, Hugging Face and Kaggle instead of guessing or asking me to do it.
- If a CLI you need is missing, stop and tell me to run `~/.gemini/scripts/setup.sh --install`. Do not install it yourself.
- To show me an image, chart, PDF or HTML report, run `show <file>`. To check a chart yourself, view the image file.

## Personal guidelines

@[GEMINI.self.md](GEMINI.self.md)
