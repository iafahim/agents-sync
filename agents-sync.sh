#!/usr/bin/env bash
# =============================================================================
# AGENTS-SYNC | v1.0.0 | Synchronize AGENTS.md across all projects
# =============================================================================
#
# Keeps your AGENTS.md configuration files synchronized across all projects.
# Maintains a global template and can update all project instances.
#
# Usage:
#   agents-sync init              Initialize global template
#   agents-sync local             Sync current directory only
#   agents-sync global            Sync all projects across entire PC
#   agents-sync edit              Edit global template
#   agents-sync status            Show configuration and statistics
#
# Options:
#   --source <file>   Source file for init
#   --path <dir>      Specific path to scan (for global mode)
#   --patterns <list> File patterns to search (comma-separated)
#   --dry-run         Preview changes without applying
#   --force           Skip confirmation prompts
#   --show-path       Show template path only (for edit command)
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_VERSION="1.0.0"
CONFIG_DIR="${HOME}/.agents-sync"
CONFIG_PATH="${CONFIG_DIR}/config.json"
TEMPLATE_PATH="${CONFIG_DIR}/template.md"

DEFAULT_PATTERNS=("AGENTS.md" "CLAUDE.md" "GEMINI.md" "CLAUDE.md.local")

# Directories to exclude from search (path components)
# Note: These are matched as directory components, so "tmp" would match "/tmp/" in paths
EXCLUDED_DIRS=("node_modules" ".git" "vendor" "bin" "obj" "build" "dist" ".vs" ".idea" "target" ".venv" "venv" "env" ".env" "cache" ".cache" "temp" ".tmp")

# System/user directories that are unlikely to contain project AGENTS files
SKIP_DIRS=("System Volume Information" '$RECYCLE.BIN' "Windows" "Program Files" "Program Files (x86)" "ProgramData" "usr" "bin" "sbin" "lib" "etc" "var" "sys" "proc" "dev" "run" "boot" "opt" "srv" "media" "mnt" ".local" ".config" ".cache" ".npm" ".yarn" ".vscode" ".idea" ".cursor")

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    echo -e "\033[36m[INFO]\033[0m $*"
}

log_success() {
    echo -e "\033[32m[OK]\033[0m $*"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $*"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        log_info "Created config directory: $CONFIG_DIR"
    fi

    if [[ ! -f "$CONFIG_PATH" ]]; then
        cat > "$CONFIG_PATH" << EOF
{
  "version": "1.0.0",
  "templatePath": "$TEMPLATE_PATH",
  "lastUpdate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "patterns": ["AGENTS.md", "CLAUDE.md", "GEMINI.md", "CLAUDE.md.local"],
  "excludedPaths": ["node_modules", ".git", "vendor", "bin", "obj", "build", "dist"]
}
EOF
        log_info "Created config file: $CONFIG_PATH"
    fi
}

get_config() {
    init_config
    cat "$CONFIG_PATH"
}

get_template_content() {
    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        return 1
    fi
    cat "$TEMPLATE_PATH"
}

set_template_content() {
    local content="$1"

    # Ensure config directory exists before writing
    init_config

    echo "$content" > "$TEMPLATE_PATH"

    local last_update=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local config=$(get_config)
    # Update lastUpdate using sed instead of jq for better compatibility
    echo "$config" | sed "s/\"lastUpdate\": \"[^\"]*\"/\"lastUpdate\": \"$last_update\"/" > "$CONFIG_PATH.tmp"
    mv "$CONFIG_PATH.tmp" "$CONFIG_PATH"
}

is_excluded_dir() {
    local path="$1"
    local basename=$(basename "$path")

    # Check EXCLUDED_DIRS (path components)
    for excluded in "${EXCLUDED_DIRS[@]}"; do
        if echo "$path" | grep -qE "/$excluded(/|$)"; then
            return 0
        fi
    done

    # Check SKIP_DIRS - check both the basename and parent directory names
    for skip in "${SKIP_DIRS[@]}"; do
        if [[ "$basename" == "$skip" ]]; then
            return 0
        fi
        # Also check if any parent directory is in SKIP_DIRS
        if echo "$path" | grep -qE "/$skip(/|\$)"; then
            return 0
        fi
    done

    return 1
}

find_ai_doc_files() {
    local root_path="$1"
    shift
    local patterns=("$@")

    >&2 log_info "Scanning: $root_path (depth-by-depth)"

    local results=()
    local max_depth=6
    local current_depth=0

    # Normalize root path (remove trailing slash)
    root_path="${root_path%/}"

    # Use breadth-first search: process each depth level before going deeper
    while [[ $current_depth -le $max_depth ]]; do
        local dirs_at_depth=()

        if [[ $current_depth -eq 0 ]]; then
            # Start with root path
            dirs_at_depth=("$root_path")
        else
            # Find all directories at current depth using mindepth/maxdepth
            while IFS= read -r -d '' dir; do
                if [[ -d "$dir" ]] && ! is_excluded_dir "$dir"; then
                    dirs_at_depth+=("$dir")
                fi
            done < <(find "$root_path" -mindepth $current_depth -maxdepth $current_depth -type d -print0 2>/dev/null || true)
        fi

        # Search for pattern files in directories at current depth
        for dir in "${dirs_at_depth[@]}"; do
            if [[ ! -d "$dir" ]] || is_excluded_dir "$dir"; then
                continue
            fi

            for pattern in "${patterns[@]}"; do
                while IFS= read -r -d '' file; do
                    if [[ -f "$file" ]] && ! is_excluded_dir "$file"; then
                        results+=("$file")
                    fi
                done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null || true)
            done
        done

        ((current_depth++)) || true
    done

    # DEBUG: Uncomment to see what's being returned
    # >&2 echo "DEBUG: Returning ${#results[@]} files"
    # >&2 printf '%s\n' "${results[@]}" | >&2 cat -A

    printf '%s\n' "${results[@]}" | sort -u
}

show_diff() {
    local old_path="$1"
    local new_content="$2"

    if [[ ! -f "$old_path" ]]; then
        echo -e "  \033[32m[NEW]\033[0m File will be created"
        return
    fi

    local old_content=$(cat "$old_path")

    if [[ "$old_content" == "$new_content" ]]; then
        echo -e "  \033[90m[SKIP]\033[0m No changes needed"
        return
    fi

    local old_lines=$(echo "$old_content" | wc -l | tr -d ' ')
    local new_lines=$(echo "$new_content" | wc -l | tr -d ' ')

    echo -e "  \033[33m[DIFF]\033[0m Content differs:"
    echo "    Lines: $old_lines -> $new_lines"

    # Show first few differing lines (limited output)
    diff -u <(echo "$old_content") <(echo "$new_content") 2>&1 | head -n 20 || :
}

sync_file() {
    local target_path="$1"
    local content="$2"

    if [[ -f "$target_path" ]]; then
        local backup_path="${target_path}.backup"
        cp "$target_path" "$backup_path"
        log_info "Backup created: $backup_path"
    else
        local dir=$(dirname "$target_path")
        mkdir -p "$dir"
    fi

    echo "$content" > "$target_path"
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

cmd_help() {
    cat << 'EOF'

AGENTS-SYNC v1.0.0
==================

Synchronize AGENTS.md across all your projects.

USAGE:
    agents-sync <command> [options]

COMMANDS:
    init              Initialize global template from current directory
    local             Sync current directory only
    global            Sync all projects across entire PC
    edit              Edit global template
    status            Show configuration and statistics

OPTIONS:
    --source <file>   Source file for init (default: ./AGENTS.md)
    --path <dir>      Specific path to scan (for global mode)
    --patterns <list> File patterns to search (comma-separated)
    --dry-run         Preview changes without applying
    --force           Skip confirmation prompts
    --show-path       Show template path only (for edit command)

EXAMPLES:
    agents-sync init
    agents-sync local
    agents-sync global --dry-run
    agents-sync global --path ~/Projects
    agents-sync edit
    agents-sync status

EOF
}

cmd_init() {
    local source_path="${ARG_SOURCE:-./AGENTS.md}"

    if [[ ! -f "$source_path" ]]; then
        log_error "Source file not found: $source_path"
        log_info "Creating empty template..."

        local empty_template='# AGENTS.md Template

This is your global AGENTS.md template. Edit this file to define
your standard AI agent instructions that will be synchronized across
all your projects.

## Project Context

Add project-specific context here.

## Coding Standards

Define your coding standards and conventions.

## Development Workflow

Describe your preferred development workflow here.
'
        set_template_content "$empty_template"
    else
        local content=$(cat "$source_path")
        set_template_content "$content"
        log_success "Template created from: $source_path"
    fi

    log_info "Template location: $TEMPLATE_PATH"
    log_info "Run 'agents-sync edit' to modify the template"
}

cmd_local() {
    local config=$(get_config)
    local template=$(get_template_content)

    if [[ -z "$template" ]]; then
        log_error "No template found. Run 'agents-sync init' first."
        return 1
    fi

    local current_path=$(pwd)
    local target_file="${current_path}/AGENTS.md"

    log_info "Current directory: $current_path"
    log_info "Target file: $target_file"
    echo ""

    show_diff "$target_file" "$template"

    if [[ "${ARG_DRY_RUN:-0}" == "1" ]]; then
        log_warn "Dry run mode - no changes applied"
        return 0
    fi

    if [[ "${ARG_FORCE:-0}" != "1" ]]; then
        read -p "Apply changes? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    sync_file "$target_file" "$template"
    log_success "Synced: $target_file"
}

cmd_global() {
    local config=$(get_config)
    local template=$(get_template_content)

    if [[ -z "$template" ]]; then
        log_error "No template found. Run 'agents-sync init' first."
        return 1
    fi

    local patterns_str="${ARG_PATTERNS:-}"
    if [[ -n "$patterns_str" ]]; then
        IFS=',' read -ra patterns <<< "$patterns_str"
    else
        patterns=("AGENTS.md" "CLAUDE.md" "GEMINI.md" "CLAUDE.md.local")
    fi

    echo ""
    echo "============================================================================"
    echo "GLOBAL SYNC MODE"
    echo "============================================================================"
    echo ""

    local all_files=()

    if [[ -n "${ARG_PATH:-}" ]]; then
        if [[ ! -d "$ARG_PATH" ]]; then
            log_error "Path not found: $ARG_PATH"
            return 1
        fi
        mapfile -t all_files < <(find_ai_doc_files "$ARG_PATH" "${patterns[@]}")
    else
        # Determine OS-specific paths to scan
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            local search_paths=("/" "$HOME" "/Volumes")
        else
            # Linux
            local search_paths=("/" "$HOME")
        fi

        for search_path in "${search_paths[@]}"; do
            if [[ -d "$search_path" ]]; then
                mapfile -t -O "${#all_files[@]}" all_files < <(find_ai_doc_files "$search_path" "${patterns[@]}")
            fi
        done
    fi

    log_info "Found ${#all_files[@]} files to sync"
    echo ""

    local changes_needed=0

    for file in "${all_files[@]}"; do
        echo "File: $file"
        show_diff "$file" "$template"

        local current_content=""
        if [[ -f "$file" ]]; then
            current_content=$(cat "$file")
        fi

        if [[ "$current_content" != "$template" ]]; then
            ((changes_needed++)) || true
        fi

        echo "" || true
    done

    echo "============================================================================"
    echo "Files requiring changes: $changes_needed / ${#all_files[@]}"
    echo "============================================================================"
    echo ""

    if [[ "${ARG_DRY_RUN:-0}" == "1" ]]; then
        log_warn "Dry run mode - no changes applied"
        return 0
    fi

    if [[ $changes_needed -eq 0 ]]; then
        log_success "All files are already up to date"
        return 0
    fi

    if [[ "${ARG_FORCE:-0}" != "1" ]]; then
        read -p "Apply changes to all files? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    for file in "${all_files[@]}"; do
        local current_content=""
        if [[ -f "$file" ]]; then
            current_content=$(cat "$file")
        fi

        if [[ "$current_content" != "$template" ]]; then
            sync_file "$file" "$template"
            log_success "Synced: $file"
        fi
    done

    log_success "Global sync complete!"
}

cmd_edit() {
    init_config

    if [[ "${ARG_SHOW_PATH:-0}" == "1" ]]; then
        echo "$TEMPLATE_PATH"
        return 0
    fi

    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        log_warn "Template not found. Creating empty template..."
        cmd_init
    fi

    log_info "Opening template: $TEMPLATE_PATH"

    # Detect and use appropriate editor
    if [[ -n "${EDITOR:-}" ]]; then
        "$EDITOR" "$TEMPLATE_PATH"
    elif command -v code &> /dev/null; then
        code "$TEMPLATE_PATH"
    elif command -v vim &> /dev/null; then
        vim "$TEMPLATE_PATH"
    elif command -v nano &> /dev/null; then
        nano "$TEMPLATE_PATH"
    elif command -v open &> /dev/null; then
        open "$TEMPLATE_PATH"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$TEMPLATE_PATH"
    else
        log_error "No editor found. Set EDITOR environment variable."
        return 1
    fi
}

cmd_status() {
    local config=$(get_config)
    local template_exists=0
    [[ -f "$TEMPLATE_PATH" ]] && template_exists=1

    echo ""
    echo "============================================================================"
    echo "AGENTS-SYNC STATUS"
    echo "============================================================================"
    echo ""
    echo "Version:          $SCRIPT_VERSION"
    echo "Config Path:      $CONFIG_PATH"
    echo "Template Path:    $TEMPLATE_PATH"
    echo "Template Exists:  $([[ $template_exists -eq 1 ]] && echo "Yes" || echo "No")"

    if [[ $template_exists -eq 1 ]]; then
        local lines=$(wc -l < "$TEMPLATE_PATH" | tr -d ' ')
        local size=$(stat -f%z "$TEMPLATE_PATH" 2>/dev/null || stat -c%s "$TEMPLATE_PATH" 2>/dev/null || echo "0")
        echo "Template Size:    $lines lines, $size bytes"
    fi

    echo ""
    echo "Configured Patterns:"
    # Extract patterns using simpler method
    local patterns=$(echo "$config" | sed -n '/"patterns":/,/\]/p' | grep '"[^"]*"' | tr -d ' ",' | grep -v '^patterns')
    for pattern in $patterns; do
        [[ -n "$pattern" ]] && echo -e "  \033[90m- $pattern\033[0m"
    done

    echo ""
    echo "Excluded Paths:"
    local excluded=$(echo "$config" | sed -n '/"excludedPaths":/,/\]/p' | grep '"[^"]*"' | tr -d ' ",' | grep -v 'excludedPaths')
    for path in $excluded; do
        [[ -n "$path" ]] && echo -e "  \033[90m- $path\033[0m"
    done

    echo ""
    local last_update=$(echo "$config" | grep -oE '"lastUpdate"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    echo "Last Updated:     $last_update"
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

ARG_SOURCE=""
ARG_PATH=""
ARG_PATTERNS=""
ARG_DRY_RUN="0"
ARG_FORCE="0"
ARG_SHOW_PATH="0"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                ARG_SOURCE="$2"
                shift 2
                ;;
            --path)
                ARG_PATH="$2"
                shift 2
                ;;
            --patterns)
                ARG_PATTERNS="$2"
                shift 2
                ;;
            --dry-run)
                ARG_DRY_RUN="1"
                shift
                ;;
            --force)
                ARG_FORCE="1"
                shift
                ;;
            --show-path)
                ARG_SHOW_PATH="1"
                shift
                ;;
            -h|--help|help)
                cmd_help
                exit 0
                ;;
            *)
                COMMAND="$1"
                shift
                ;;
        esac
    done
}

# =============================================================================
# MAIN
# =============================================================================

COMMAND="help"
parse_args "$@"

case "$COMMAND" in
    init)   cmd_init ;;
    local)  cmd_local ;;
    global) cmd_global ;;
    edit)   cmd_edit ;;
    status) cmd_status ;;
    help)
        cmd_help
        exit 0
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
