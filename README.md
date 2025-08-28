# kavow

A comprehensive, TUI-driven automation system that transforms any macOS machine into a fully configured development environment. Built entirely in Bash with a focus on modularity, reliability, and user experience.

## Features

🎯 **Zero-Configuration Setup** - Single command starts the entire process
🎨 **Modern Terminal UI** - Clean, intuitive interface using `gum`
📦 **Homebrew Integration** - All applications installed via Homebrew
🔧 **Git & GitHub Ready** - Automated SSH key generation and GitHub CLI setup
💾 **State Recovery** - Resume from any interruption point
🎛️ **Modular Design** - Easy to extend and customize

## Quick Start

```bash
git clone https://github.com/your-username/kavow.git
cd kavow
./setup.sh
```

The script will guide you through:
1. Homebrew installation verification
2. Application selection by category
3. Git and GitHub configuration
4. SSH key generation and setup

## Application Categories

### 🎵 Productivity
- Spotify - Music streaming
- 1Password - Password manager
- Discord - Communication
- Slack - Team collaboration
- Obsidian - Note-taking
- Todoist - Task management

### 💻 Development

**IDEs & Editors**
- VSCode - Code editor
- IntelliJ IDEA - Java/Kotlin IDE
- Zed - High-performance editor
- Cursor - AI-powered editor

**AI Tools**
- Claude Code - AI coding assistant

**Development Tools**
- Python - Programming language
- Node.js - JavaScript runtime

**Terminals**
- Ghostty - GPU-accelerated terminal
- Warp - Modern terminal with AI features
- iTerm2 - Feature-rich terminal

## Project Structure

```
├── setup.sh                 # Main entry point
├── lib/                     # Core utilities
│   ├── ui_hybrid.sh        # Hybrid TUI framework (gum + native fallback)
│   ├── state.sh            # State management
│   ├── utils.sh            # Common utilities
│   ├── brew.sh             # Homebrew operations
│   └── installer.sh        # Installation logic
├── modules/                 # Feature modules
│   ├── apps/               # Application definitions
│   │   ├── productivity.sh
│   │   └── development.sh
│   ├── git/                # Git configuration
│   └── github/             # GitHub setup
└── data/                   # Configuration data
    └── apps.conf           # Application metadata
```

## Architecture Principles

Following **Basecamp's Omarchy** philosophy ([omarchy.org](https://omarchy.org)):

- **Clear Boundaries** - Each module has a single responsibility
- **Minimal Interfaces** - Simple function signatures and data flow
- **No Premature Abstraction** - Concrete solutions over generic frameworks
- **Fail Fast** - Early validation with clear error messages

*Built with ❤️ following [Omarchy principles](https://omarchy.org) for maintainable software architecture*

## State Management

The system maintains state in `~/.kavow/state.json` to enable recovery:

```json
{
  "current_stage": "app_selection",
  "homebrew_installed": true,
  "selected_apps": ["vscode", "spotify", "1password"],
  "git_configured": false,
  "github_authenticated": false
}
```

## Recovery

If the setup is interrupted, simply run:

```bash
./setup.sh --recover
```

The system will detect the previous state and resume from the last successful step.

## Adding Custom Applications

1. Add application metadata to `data/apps.conf`:
```bash
my-app|My App|productivity|my-app|My favorite productivity app
```

2. The installer will automatically detect and include it in the relevant category.

## Requirements

- macOS 10.15+ (Catalina or later)
- Terminal with 256 color support
- Internet connection for downloads

## Development

The project follows strict Bash guidelines:
- No inline comments (self-documenting code)
- Modular architecture with clear interfaces
- Comprehensive error handling
- State-driven flow control

### Running Tests

```bash
./test/run_tests.sh
```

### Code Style

- Functions use `snake_case`
- Constants use `UPPER_CASE`
- Local variables declared with `local`
- All scripts have `set -euo pipefail`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the existing code style
4. Add tests for new functionality
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

---