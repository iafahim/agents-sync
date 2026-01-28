# agents-sync

> Synchronize AGENTS.md across all your projects with one command

**agents-sync** is a cross-platform CLI tool that keeps your AGENTS.md configuration files synchronized across all projects. It maintains a global template and can update all project-specific instances with a single command.

## Features

- **Global Template Management**: Store one master AGENTS.md template
- **Depth-by-Depth Traversal**: Efficiently scans directories level by level (BFS)
- **Smart Filtering**: Automatically excludes build artifacts and system directories
- **Auto-Discovery**: Finds all AGENTS.md, CLAUDE.md, GEMINI.md files
- **Safety First**: Shows diff preview before applying changes
- **Cross-Platform**: Works on Windows, macOS, and Linux

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

## Quick Start

```bash
# 1. Create your global template from an existing file
agents-sync template --source ./AGENTS.md

# 2. Drop AGENTS.md in any directory (no args needed!)
cd my-project
agents-sync

# 3. Scan and sync all projects across your computer
agents-sync scan --dry-run  # Preview first
agents-sync scan             # Apply changes
```

## Commands

### Default Behavior (No Arguments)

Drops AGENTS.md in the current directory from your global template.

```
┌─────────────────────────────────────────────────────────────┐
│                    agents-sync                              │
│                    (no arguments)                           │
├─────────────────────────────────────────────────────────────┤
│  FROM:  ~/.agents-sync/template.md                         │
│  TO:    ./AGENTS.md (current directory)                    │
│                                                             │
│  1. Reads global template                                  │
│  2. Compares with local AGENTS.md (if exists)              │
│  3. Shows diff preview                                     │
│  4. Creates backup if overwriting                          │
│  5. Writes new content to ./AGENTS.md                      │
└─────────────────────────────────────────────────────────────┘
```

**Usage:**
```bash
# Most common usage - just drop the file in current directory
cd my-project
agents-sync

# With options
agents-sync --dry-run     # Preview changes
agents-sync --force       # Skip confirmation
```

### `template` - Create/Update Global Template

Creates or updates your global AGENTS.md template from an existing file.

```
┌─────────────────────────────────────────────────────────────┐
│                 agents-sync template                       │
├─────────────────────────────────────────────────────────────┤
│  FROM:  ./AGENTS.md (or --source <file>)                   │
│  TO:    ~/.agents-sync/template.md                         │
│                                                             │
│  1. Reads content from source file                         │
│  2. Creates ~/.agents-sync/ directory                     │
│  3. Saves content as template.md                           │
│  4. Creates config.json with metadata                      │
└─────────────────────────────────────────────────────────────┘
```

**Usage:**
```bash
# Create template from current directory's AGENTS.md
agents-sync template

# Use a custom file as template
agents-sync template --source ./my-instructions.md

# Creates empty template if source not found
agents-sync template --source ./non-existent.md
```

### `scan` - Scan and Sync All Projects

Scans your entire computer (or a specific path) and syncs all matching files.

```
┌─────────────────────────────────────────────────────────────┐
│                   agents-sync scan                          │
├─────────────────────────────────────────────────────────────┤
│  SCANS: /, ~/home, or --path <dir> (depth-by-depth)        │
│  FINDS: AGENTS.md, CLAUDE.md, GEMINI.md, etc.              │
│  FROM:  ~/.agents-sync/template.md                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Depth 0: /home/user/projects/                       │   │
│  │    ├── project1/AGENTS.md           ← Found ✓        │   │
│  │    └── project2/CLAUDE.md           ← Found ✓        │   │
│  │                                                         │   │
│  │  Depth 1: /home/user/projects/project1/               │   │
│  │    ├── src/CLAUDE.md                  ← Found ✓        │   │
│  │    └── docs/AGENTS.md                  ← Found ✓        │   │
│  │                                                         │   │
│  │  Depth 2: /home/user/projects/project1/src/           │   │
│  │    └── utils/GEMINI.md                 ← Found ✓        │   │
│  │                                                         │   │
│  │  (Excludes: node_modules/, .git/, usr/, bin/, etc.)   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  For each file found:                                      │
│    1. Compare with template                                │
│    2. Show diff                                            │
│    3. Create backup (.backup)                              │
│    4. Update file with template content                    │
└─────────────────────────────────────────────────────────────┘
```

**Usage:**
```bash
# Scan entire computer (all drives on Windows, / and ~ on Unix)
agents-sync scan

# Preview all changes without applying
agents-sync scan --dry-run

# Scan only specific directory
agents-sync scan --path ~/Projects

# Scan specific path with custom patterns
agents-sync scan --path ~/code --patterns "AGENTS.md,PROMPT.md"

# Force skip all confirmations
agents-sync scan --force
```

**What Gets Scanned:**
- Searches up to 6 directories deep
- Processes directories level-by-level (BFS traversal)
- Finds: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CLAUDE.md.local`

**What Gets Skipped:**
- Build artifacts: `node_modules/`, `target/`, `dist/`, `build/`, `.venv/`
- Version control: `.git/`, `.svn/`
- System directories: `usr/`, `bin/`, `sbin/`, `etc/`, `var/`, `sys/`, `proc/`
- Cache directories: `.cache/`, `tmp/`, `temp/`, `.npm/`, `.yarn/`
- Config directories: `.config/`, `.local/`, `.vscode/`, `.idea/`, `.cursor/`

### `edit` - Edit Global Template

Opens your global template in your default editor.

```
┌─────────────────────────────────────────────────────────────┐
│                    agents-sync edit                         │
├─────────────────────────────────────────────────────────────┤
│  Opens: ~/.agents-sync/template.md                         │
│                                                             │
│  Editor priority:                                          │
│    1. $EDITOR environment variable                         │
│    2. code (VS Code)                                       │
│    3. vim                                                  │
│    4. nano                                                 │
│    5. open (macOS) / xdg-open (Linux)                     │
└─────────────────────────────────────────────────────────────┘
```

**Usage:**
```bash
# Open in default editor
agents-sync edit

# Show template path only (useful for scripting)
agents-sync edit --show-path
```

### `status` - Show Configuration

Displays current configuration and statistics.

```
┌─────────────────────────────────────────────────────────────┐
│                   agents-sync status                        │
├─────────────────────────────────────────────────────────────┤
│  Version:          1.0.0                                    │
│  Config Path:      ~/.agents-sync/config.json              │
│  Template Path:    ~/.agents-sync/template.md              │
│  Template Exists:  Yes                                      │
│  Template Size:    42 lines, 1234 bytes                    │
│                                                             │
│  Configured Patterns:                                      │
│    - AGENTS.md                                               │
│    - CLAUDE.md                                               │
│    - GEMINI.md                                               │
│    - CLAUDE.md.local                                         │
│                                                             │
│  Excluded Paths:                                            │
│    - node_modules                                           │
│    - .git                                                    │
│    - vendor                                                  │
│    - ...                                                     │
│                                                             │
│  Last Updated:     2026-01-28T12:00:00Z                    │
└─────────────────────────────────────────────────────────────┘
```

**Usage:**
```bash
agents-sync status
```

## Examples

### Use Case 1: Set Up New Project

Starting a new project and want your standard AGENTS.md.

```bash
cd my-new-project
agents-sync
```

### Use Case 2: Update Guidelines Across All Projects

You've improved your coding guidelines and want all projects to use them.

```bash
# 1. Edit the global template with your new guidelines
agents-sync edit

# 2. Preview changes across all projects
agents-sync scan --dry-run

# 3. Apply changes to all projects
agents-sync scan
```

### Use Case 3: Create Template from Existing Project

You have a well-configured project and want to use it as template.

```bash
cd my-well-configured-project
agents-sync template --source ./AGENTS.md
```

### Use Case 4: Sync Only Specific Directory

You want to sync projects in a specific folder without scanning entire computer.

```bash
agents-sync scan --path ~/Projects --dry-run
agents-sync scan --path ~/Projects
```

### Use Case 5: Quick Drop in Multiple Projects

Drop AGENTS.md in multiple projects quickly.

```bash
for dir in project1 project2 project3; do
    cd ~/Projects/$dir
    agents-sync --force
done
```

## How It Works

### Directory Structure

```
~/.agents-sync/
├── config.json      # Configuration and metadata
└── template.md      # Your global AGENTS.md template
```

### Traversal Algorithm

**Depth-by-Depth (BFS)**: Instead of recursively diving into each directory, agents-sync processes directories level by level:

```
project/
├── AGENTS.md              ← Depth 0: Processed first
├── src/
│   ├── CLAUDE.md          ← Depth 1: Processed second
│   └── utils/
│       └── GEMINI.md      ← Depth 2: Processed third
└── tests/
    └── AGENTS.md          ← Depth 1: Processed second
```

This is more efficient and prevents issues with deeply nested directory structures.

### Safety Features

- **Dry Run Mode**: Preview changes before applying (`--dry-run`)
- **Confirmation Prompt**: Always asks before overwriting (unless `--force`)
- **Backup Creation**: Creates `.backup` file before overwriting
- **Smart Exclusions**: Automatically skips build/cache directories
- **Diff Preview**: Shows exactly what will change

## Configuration

Global config location: `~/.agents-sync/config.json`

```json
{
  "version": "1.0.0",
  "templatePath": "~/.agents-sync/template.md",
  "lastUpdate": "2026-01-28T12:00:00Z",
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
    "obj",
    "build",
    "dist"
  ]
}
```

## Development

### Running Tests

```powershell
# Windows
.\test.ps1

# macOS/Linux
./test.sh

# Comprehensive test suite (20 tests)
./test-comprehensive.sh
```

## Command Reference Summary

| Command | Description | Alias |
|---------|-------------|-------|
| `agents-sync` | Sync current directory (default) | - |
| `agents-sync template` | Create/update global template | - |
| `agents-sync scan` | Scan and sync all projects | - |
| `agents-sync edit` | Edit global template | - |
| `agents-sync status` | Show configuration | - |
| `agents-sync help` | Show help message | - |

## License

MIT License - see LICENSE file for details

## Author

Created by IAFahim

---

**Tip**: Use `--dry-run` flag to preview changes before applying them globally!
