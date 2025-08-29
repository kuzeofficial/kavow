# kavow

A comprehensive, TUI-driven automation system that transforms any macOS machine into a fully configured development environment. Inspired by my personal need to quickly configure Mac devices every time I changed them, **kavow** streamlines the entire setup process from applications to programming languages.

Built entirely in Bash following **Omarchy principles** ([omarchy.org](https://omarchy.org)), which I've been using in other devices and find absolutely beautiful for creating maintainable software architecture.

## Features

🎯 **Zero-Configuration Setup** - Single command starts the entire process
🎨 **Modern Terminal UI** - Clean, intuitive interface using `gum`
📦 **Dual Package Management** - Homebrew for applications, mise for programming languages
🐍 **Programming Languages** - Choose from Python, Node.js, Ruby, Go, Rust, Java, PHP
🔧 **Complete Git & GitHub Setup** - Automated SSH key generation and GitHub CLI authentication
💾 **State Recovery** - Resume from any interruption point with full context
🎛️ **Modular Architecture** - Easy to extend and customize following Omarchy principles
🔄 **Smart Version Management** - Automatic language version handling via mise

## Quick Start

```bash
git clone https://github.com/kuzeofficial/kavow.git
cd kavow
./setup.sh
```

The script will guide you through:
1. Homebrew installation verification
2. Application selection by category
3. Programming language selection (Python, Node.js, Ruby, Go, Rust, Java, PHP)
4. Automated language installation via mise
5. Git and GitHub configuration
6. SSH key generation and GitHub authentication

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

**Terminals**
- Ghostty - GPU-accelerated terminal
- Warp - Modern terminal with AI features
- iTerm2 - Feature-rich terminal

## Programming Languages

Choose from these programming languages, automatically installed via **mise** version manager:

### 🐍 **Core Languages**
- **Python 3.13** - Interpreted, interactive, object-oriented programming language
- **Node.js (latest)** - Platform built on V8 to build network applications
- **Ruby (latest)** - Dynamic, open source programming language with a focus on simplicity

### ⚡ **Systems Languages**
- **Go (latest)** - Open source programming language supported by Google
- **Rust (latest)** - Empowering everyone to build reliable and efficient software
- **Java (latest)** - Class-based, object-oriented programming language

### 🌐 **Web Languages**
- **PHP (latest)** - Popular general-purpose scripting language

## Project Structure

```
├── setup.sh                 # Main entry point with kavow banner
├── LICENSE                  # MIT License
├── lib/                     # Core utilities following Omarchy principles
│   ├── ui_hybrid.sh        # Hybrid TUI framework (gum + native fallback)
│   ├── ui_native.sh        # Native bash UI functions
│   ├── state.sh            # State management and recovery
│   ├── utils.sh            # Common utilities and validation
│   ├── brew.sh             # Homebrew operations wrapper
│   ├── gum_manager.sh      # GUM auto-install manager
│   └── installer.sh        # Application and language installation logic
├── modules/                 # Feature modules with clear boundaries
│   ├── git/                # Git configuration module
│   │   └── setup.sh        # Git identity and settings
│   ├── github/             # GitHub integration module
│   │   └── auth.sh         # GitHub CLI and SSH key setup
│   ├── mise/               # Language version management module
│   │   └── setup.sh        # Programming language installation
│   └── ssh/                # SSH key management module
│       └── keygen.sh       # SSH key generation utilities
├── data/                   # Configuration data (no code)
│   ├── apps.conf           # Application metadata and categories
│   ├── categories.conf     # Application category definitions
│   └── languages.conf      # Programming language definitions
├── preflight/              # System validation module
│   └── guard.sh            # macOS compatibility and prerequisite checks
└── test/                   # Test suite
    ├── run_tests.sh        # Test runner
    ├── unit/               # Unit tests
    └── integration/        # Integration tests
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
  "version": "1.0.0",
  "current_stage": "language_selection",
  "homebrew_installed": true,
  "gum_installed": true,
  "selected_apps": ["vscode", "spotify"],
  "installed_apps": ["vscode", "spotify"],
  "failed_apps": [],
  "selected_languages": ["python", "nodejs"],
  "installed_languages": ["python", "nodejs"],
  "failed_languages": [],
  "git_configured": false,
  "mise_configured": true,
  "github_authenticated": false,
  "ssh_key_generated": false,
  "setup_complete": false
}
```

## Recovery

If the setup is interrupted, simply run:

```bash
./setup.sh --recover
```

The system will detect the previous state and resume from the last successful step.

## Customization

### Adding Custom Applications

1. Add application metadata to `data/apps.conf`:
```bash
my-app|My App|productivity|brew install --cask my-app|My favorite productivity app
```

2. The installer will automatically detect and include it in the relevant category.

### Adding Custom Programming Languages

1. Add language metadata to `data/languages.conf`:
```bash
kotlin|Kotlin|Modern programming language for JVM|latest
```

2. Users can select it during the language selection phase, and it will be installed via mise.

### Modifying Categories

Edit `data/categories.conf` to add or modify application categories:
```bash
MyCategory|🎯 My Tools|Custom tools for my workflow|3
```

## Requirements

- macOS 10.15+ (Catalina or later)
- Terminal with 256 color support
- Internet connection for downloads

## Motivation

**kavow** was born from my personal frustration of having to manually configure Mac devices every time I changed them. Whether it was a new work laptop, upgrading to a new Mac, or helping friends/family set up their development environments, the process was always repetitive and time-consuming.

I've been using **Omarchy principles** in other devices and projects, and I find the approach absolutely beautiful for creating maintainable, modular software. The clear boundaries, minimal interfaces, and fail-fast philosophy resonate deeply with how I think about software architecture.

This project represents the perfect marriage of personal necessity and architectural elegance - solving a real problem while demonstrating how beautiful code organization can make complex automation feel simple and reliable.

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

## About kavow

**kavow** (/kaˈvoʊ/) - A personal automation project that makes setting up development environments on macOS as simple as saying "kavow" ✨

*Built with ❤️ and a lot of late-night "why do I have to do this again?" moments*

---

*"The best code is the code you don't have to write twice"* - Every developer who's ever set up a new machine