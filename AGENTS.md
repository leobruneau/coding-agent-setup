# Instructions for coding agents

If the user asks you to set up their machine from this repository, follow these steps.

1. Check for `git` and `jq`. If `jq` is missing, install it (`brew install jq` on macOS,
   `sudo apt install jq` on Debian or Ubuntu) or ask the user to.
2. Clone the repo to `~/Documents/GithubRepos/coding-agent-setup`, or `git pull` if it is already there.
   Don't use a temporary folder: `install.sh` creates symlinks into the clone.
3. Run `./install.sh --dry-run` and show the user which files it would back up and replace, and the
   settings diff. Ask before going on if it would replace a file that the repo doesn't already track.
4. Run `./install.sh`.
5. Tell the user to restart Claude Code and run `/plugin` to check that the plugins in
   `claude/settings.json` under `enabledPlugins` are installed. Install any missing one with
   `claude plugin install <name>@<marketplace>`.
6. Report the backup folder path that `install.sh` printed.

If the user asks you to save their current setup, run `./capture.sh`, show `git diff`, and commit
and push after they approve.

Never copy `~/.claude.json`, `~/.claude/history.jsonl`, `~/.claude/projects/` or other session data into
this repo. They hold account details and conversation history.
