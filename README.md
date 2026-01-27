# agents-sync

> Synchronize AGENTS.md across all your projects with one command

**agents-sync** is a cross-platform CLI tool that keeps your AGENTS.md configuration files synchronized across all projects. It maintains a global template and can update all project-specific instances with a single command.

## Features

- **Global Template Management**: Store one master AGENTS.md template
- **Two Modes**:
  - `local` - Sync current directory only
  - `global` - Sync all projects across your entire PC
- **Auto-Discovery**: Finds all AGENTS.md, CLAUDE.md, GEMINI.md files
- **Smart Safety**: Shows diff before applying changes
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Git Integration**: Works seamlessly with git repositories

## Installation

### Windows (PowerShell)

```powershell
# Online installation (recommended)
iwr -useb https://raw.githubusercontent.com/IAFahim/agents-sync/main/install.ps1 | iex

# Manual installation
git clone https://github.com/IAFahim/agents-sync.git
cd agents-sync
.\install.ps1
```

### macOS/Linux (Bash)

```bash
# Online installation (recommended)
curl -fsSL https://raw.githubusercontent.com/IAFahim/agents-sync/main/install.sh | sh

# Manual installation
git clone https://github.com/IAFahim/agents-sync.git
cd agents-sync
chmod +x install.sh
sudo ./install.sh
```

## Usage

### First Time Setup

When you first run `agents-sync`, it will:
1. Create a global template at `~/.agents-sync/template.md`
2. Open it in your default editor
3. Wait for you to save your template

```bash
# Initialize with current directory's AGENTS.md as template
agents-sync init

# Or specify a custom file as template
agents-sync init --source ./my-template.md
```

### Local Mode (Current Directory Only)

Sync only the current directory:

```bash
# Sync current directory (creates or updates AGENTS.md)
agents-sync local

# Dry run - show what would change
agents-sync local --dry-run

# Force overwrite without confirmation
agents-sync local --force
```

### Global Mode (All Projects)

Sync all AGENTS.md files across your entire PC:

```bash
# Sync all projects (scans all drives)
agents-sync global

# Dry run - preview all changes
agents-sync global --dry-run

# Scan specific directory only
agents-sync global --path "D:\Projects"

# Include specific file patterns
agents-sync global --patterns "AGENTS.md,CLAUDE.md,GEMINI.md"
```

### Edit Global Template

```bash
# Opens global template in default editor
agents-sync edit

# Show template location
agents-sync edit --show-path
```

### Show Status

```bash
# Show global template location and stats
agents-sync status
```

## How It Works

1. **Global Template**: Stored at `~/.agents-sync/template.md`
2. **Auto-Discovery**: Scans all drives for AI documentation files
3. **Safety First**: Always shows preview before applying changes
4. **Smart Detection**: Recognizes `.git` folders and respects project boundaries

### File Patterns Searched

- `AGENTS.md` - Agent instructions
- `CLAUDE.md` - Claude-specific instructions
- `GEMINI.md` - Gemini-specific instructions
- `CLAUDE.md.local` - Local Claude overrides

### Directories Scanned

- User profile: `~/.gemini`, `~/.claude`, `~/.cursor`, `~/.craft-agent`
- AppData Roaming: `%APPDATA%\Claude`, `%APPDATA%\Cursor`, etc.
- AppData Local: `%LOCALAPPDATA%\Claude`, etc.
- All drives: Recursively searches for AI-named folders

## Examples

### Use Case 1: Update Guidelines Across All Projects

You've improved your coding guidelines and want all projects to use them:

```bash
# 1. Edit the global template
agents-sync edit

# 2. Preview changes across all projects
agents-sync global --dry-run

# 3. Apply changes
agents-sync global
```

### Use Case 2: Set Up New Project

Starting a new project and want your standard AGENTS.md:

```bash
cd my-new-project
agents-sync local
```

### Use Case 3: Create Template from Existing Project

You have a well-configured project and want to use it as template:

```bash
cd my-well-configured-project
agents-sync init --source ./AGENTS.md
```

## Configuration

Global template location: `~/.agents-sync/config.json`

```json
{
  "version": "1.0.0",
  "templatePath": "~/.agents-sync/template.md",
  "lastUpdate": "2026-01-27T12:00:00Z",
  "patterns": [
    "AGENTS.md",
    "CLAUDE.md",
    "GEMINI.md",
    "CLAUDE.md.local"
  ],
  "excludedPaths": [
    "node_modules",
    ".git",
    "vendor",
    "bin",
    "obj"
  ]
}
```

## Safety Features

- **Dry Run Mode**: Preview changes before applying
- **Confirmation Prompt**: Always asks before overwriting
- **Backup Creation**: Creates `.backup` before overwriting
- **Excluded Directories**: Ignores common build/cache directories
- **Git-Aware**: Won't modify files in `.git` directory

## Development

### Running Tests

```powershell
# Windows
.\test.ps1

# macOS/Linux
./test.sh
```

### Project Structure

```
agents-sync/
├── .github/workflows/
│   └── test.yml              # CI/CD pipeline
├── agents-sync.ps1           # PowerShell implementation
├── agents-sync.sh            # Bash implementation
├── install.ps1               # Windows installer
├── install.sh                # Unix installer
├── test.ps1                  # Windows tests
├── test.sh                   # Unix tests
└── README.md                 # This file
```

## License

MIT License - see LICENSE file for details

## Author

Created by IAFahim

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Tip**: Use `--dry-run` flag to preview changes before applying them globally!
