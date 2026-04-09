# fliggy agents

![fliggy agents](hero-thumbnail.png)

Tiny AI companions that live on your macOS dock.

## Source Of Truth

The runtime source of truth for local development is:

`/Users/tianzhongyi/Documents/fliggy agents/fliggy-agents/build/src/FliggyAgents`

`build/patched` is no longer the runtime source of truth for the app you install and verify.
Use `build/src/FliggyAgents` plus the Xcode project in `build/src/fliggy-agents.xcodeproj` for all product changes, builds, and acceptance checks.

## Reliability Workflow

Use one build chain only:

1. Source: `build/src/FliggyAgents`
2. Build command:
   `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project fliggy-agents/build/src/fliggy-agents.xcodeproj -scheme FliggyAgents -configuration Debug CODE_SIGNING_ALLOWED=NO build`
3. Install target:
   `~/Applications/fliggy agents.app`

For repeatable local install + backup, run:

```bash
./fliggy-agents/build/src/scripts/install_debug_app.sh
```

The install script will:

- build the Debug app from `build/src`
- back up any existing `~/Applications/fliggy agents.app`
- install the freshly built app with `ditto`
- avoid the nested `.app` copy bug caused by `cp -R`

## Features

- Animated characters rendered from transparent HEVC video
- Click a character to chat with AI in a themed popover terminal
- Switch between Claude, Codex, Copilot, Qoder, and Gemini from the menubar
- Setup checklist and notification status center for permissions and readiness
- Unified `助手提醒` inbox for proactive reminders and mirrored DingTalk notifications
- Local skill execution powered by Codex, with workspace selection directly from chat
- Thinking bubbles, completion sounds, and desktop notification mirroring

## Requirements

- macOS Sonoma (14.0+) or newer
- Full Xcode installed at `/Applications/Xcode.app`
- At least one supported CLI installed:
  - [Claude Code](https://claude.ai/download)
  - [OpenAI Codex](https://github.com/openai/codex)
  - [GitHub Copilot](https://github.com/github/copilot-cli)
  - [Qoder CLI](https://www.qoder.com/)
  - [Google Gemini CLI](https://github.com/google-gemini/gemini-cli)

## Privacy

fliggy agents runs entirely on your Mac and sends no personal data anywhere on its own.
AI provider traffic is handled by the local CLI you selected.

## License

MIT License. See [LICENSE](LICENSE) for details.
