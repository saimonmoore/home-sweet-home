{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.4",
  "small_model": "openai/gpt-5.4-mini",
  "autoupdate": "notify",
  "share": "disabled",
  "default_agent": "build",
  "permission": {
    "edit": "allow",
    "bash": {
      "*": "allow",
      "rm -rf*": "deny",
      "git push --force*": "deny",
      "git reset --hard*": "deny",
      "npm publish*": "deny",
      "pnpm publish*": "deny",
      "yarn npm publish*": "deny"
    },
    "webfetch": "allow"
  },
  "agent": {
    "build": {
      "mode": "primary",
      "permission": {
        "edit": "allow",
        "bash": {
          "*": "allow",
          "rm -rf*": "deny",
          "git push --force*": "deny",
          "git reset --hard*": "deny",
          "npm publish*": "deny",
          "pnpm publish*": "deny",
          "yarn npm publish*": "deny"
        }
      }
    },
    "plan": {
      "mode": "primary",
      "permission": {
        "edit": "deny",
        "bash": {
          "*": "deny",
          "git status": "allow",
          "git diff*": "allow",
          "git log*": "allow",
          "git show*": "allow",
          "grep *": "allow",
          "rg *": "allow",
          "cat *": "allow",
          "ls *": "allow",
          "tree *": "allow",
          "find *": "allow",
          "wc *": "allow"
        }
      }
    }
  },
  "watcher": {
    "ignore": [
      "node_modules/**",
      ".git/**",
      "dist/**",
      "build/**",
      "target/**",
      "coverage/**",
      "__pycache__/**",
      "*.log"
    ]
  },
  "instructions": [
    "AGENTS.md"
  ]
}
