#!/usr/bin/env bash
#
# Deploy AI skills and agents to Claude Code and/or Cursor global directories.
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -t, --target <all|claude|cursor|wsl> Target tool (default: all)
#   -c, --category <agents|skills>      Deploy one category only (default: both)
#   -n, --dry-run                       Show what would change without copying
#   -d, --diff                          Show diffs between repo and deployed files
#   -f, --force                         Skip confirmation prompt
#   -h, --help                          Show this help
#
# Examples:
#   ./deploy.sh -t claude
#   ./deploy.sh -t cursor --dry-run
#   ./deploy.sh -t all -c skills --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST="$SCRIPT_DIR/deploy-manifest.json"

TARGET="all"
CATEGORY=""
DRY_RUN=false
DIFF_MODE=false
FORCE=false

# --- Argument parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target)   TARGET="$2"; shift 2 ;;
        -c|--category) CATEGORY="$2"; shift 2 ;;
        -n|--dry-run)  DRY_RUN=true; shift ;;
        -d|--diff)     DIFF_MODE=true; shift ;;
        -f|--force)    FORCE=true; shift ;;
        -h|--help)     head -20 "$0" | tail -18; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: Manifest not found at $MANIFEST" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

# --- Colors ---

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[0;90m'
NC='\033[0m'

# --- Transform functions ---

resolve_target_path() {
    echo "${1/#\~/$HOME}"
}

update_tool_names() {
    local text="$1"
    # Replace backtick-wrapped tool names
    text=$(echo "$text" | sed \
        -e 's/`Bash`/`Shell`/g' \
        -e 's/`Edit`/`StrReplace`/g' \
        -e 's/`Agent`/`Task`/g')
    # Replace tool names at word boundaries in prose
    text=$(echo "$text" | sed \
        -e 's/\bBash\b/Shell/g' \
        -e 's/\bEdit\b/StrReplace/g' \
        -e 's/\bAgent\b/Task/g')
    echo "$text"
}

update_paths() {
    echo "$1" | sed 's|~/\.claude/|~/.cursor/|g'
}

parse_frontmatter_field() {
    local content="$1"
    local field="$2"
    echo "$content" | sed -n '/^---$/,/^---$/p' | grep "^${field}:" | sed "s/^${field}: *//"
}

has_frontmatter() {
    local content="$1"
    [[ "$content" =~ ^--- ]]
}

strip_frontmatter() {
    local content="$1"
    echo "$content" | sed '1{/^---$/!q}; 1,/^---$/d'
}

build_frontmatter() {
    local name="$1"
    local description="$2"
    printf -- "---\nname: %s\ndescription: %s\n---\n" "$name" "$description"
}

parse_frontmatter_tools() {
    local content="$1"
    echo "$content" | sed -n '/^---$/,/^---$/p' | grep '^\s*-\s' | sed 's/^\s*-\s*//'
}

get_tool_constraints() {
    local tools_csv="$1"
    local full_set="Read Glob Grep Bash Edit Write WebSearch WebFetch"
    local excluded=""

    for tool in $full_set; do
        if ! echo "$tools_csv" | grep -qw "$tool"; then
            case "$tool" in
                Read)      excluded="$excluded\n- Read (file reading)" ;;
                Glob)      excluded="$excluded\n- Glob (file search)" ;;
                Grep)      excluded="$excluded\n- Grep (content search)" ;;
                Bash)      excluded="$excluded\n- Shell (command execution)" ;;
                Edit)      excluded="$excluded\n- StrReplace (file editing)" ;;
                Write)     excluded="$excluded\n- Write (file creation)" ;;
                WebSearch) excluded="$excluded\n- WebSearch (web search)" ;;
                WebFetch)  excluded="$excluded\n- WebFetch (URL fetching)" ;;
            esac
        fi
    done

    if [[ -z "$excluded" ]]; then
        return
    fi

    printf "\n## Tool Constraints\n\nThe following tools are NOT available to this agent. Do not use them:\n%b\n" "$excluded"
}

convert_agent_file() {
    local content="$1"
    local name description body header tools constraints

    name=$(parse_frontmatter_field "$content" "name")
    description=$(parse_frontmatter_field "$content" "description")
    tools=$(parse_frontmatter_tools "$content")
    body=$(strip_frontmatter "$content")

    body=$(update_tool_names "$body")
    body=$(update_paths "$body")

    if [[ -n "$tools" ]]; then
        constraints=$(get_tool_constraints "$tools")
        if [[ -n "$constraints" ]]; then
            body=$(printf "%s" "$body" | sed -e :a -e '/^\n*$/{$d;N;ba}')
            body=$(printf "%s\n%s\n" "$body" "$constraints")
        fi
    fi

    header=$(build_frontmatter "$name" "$description")
    printf "%s\n%s" "$header" "$body"
}

convert_skill_file() {
    local content="$1"
    local skill_name="$2"
    local name description body header full_text first_line

    name="$skill_name"

    if has_frontmatter "$content"; then
        description=$(parse_frontmatter_field "$content" "description")
        body=$(strip_frontmatter "$content")
    else
        description=""
        body="$content"
    fi

    if [[ -z "$description" ]]; then
        first_line=$(echo "$body" | grep -m1 '.' || true)
        description=$(echo "$first_line" | sed 's/ *Arguments: *\$ARGUMENTS *$//')
    fi

    body=$(update_tool_names "$body")
    body=$(update_paths "$body")

    header=$(build_frontmatter "$name" "$description")
    printf "%s\n%s" "$header" "$body"
}

# --- Deploy logic ---

TOTAL_CREATED=0
TOTAL_UPDATED=0
TOTAL_SKIPPED=0

deploy_section() {
    local tool_key="$1"
    local cat_key="$2"

    local source target should_transform
    source=$(jq -r ".\"$tool_key\".\"$cat_key\".source" "$MANIFEST")
    target=$(jq -r ".\"$tool_key\".\"$cat_key\".target" "$MANIFEST")
    should_transform=$(jq -r ".\"$tool_key\".\"$cat_key\".transform" "$MANIFEST")

    local excludes
    excludes=$(jq -r ".\"$tool_key\".\"$cat_key\".exclude // [] | .[]" "$MANIFEST")

    target=$(resolve_target_path "$target")
    local source_dir="$REPO_ROOT/$source"

    if [[ ! -d "$source_dir" ]]; then
        echo -e "  ${DIM}No source directory: $source_dir${NC}"
        return
    fi

    local files
    files=$(find "$source_dir" -type f | sort)

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local rel_path="${file#$source_dir}"
        rel_path="${rel_path#/}"
        local filename
        filename=$(basename "$file")

        # Check excludes
        local skip=false
        while IFS= read -r ex; do
            [[ -z "$ex" ]] && continue
            [[ "$filename" == "$ex" ]] && skip=true
        done <<< "$excludes"
        $skip && continue
        [[ "$filename" == "SKILL.cursor.md" ]] && continue

        local dest_path="$target/$rel_path"
        local source_content output_content
        source_content=$(cat "$file")
        output_content="$source_content"

        # Apply transforms for .md files
        if [[ "$should_transform" == "true" && "$file" == *.md ]]; then
            if [[ "$cat_key" == "agents" ]]; then
                output_content=$(convert_agent_file "$source_content")
            elif [[ "$cat_key" == "skills" ]]; then
                if [[ "$filename" == "SKILL.md" ]]; then
                    local cursor_override
                    cursor_override="$(dirname "$file")/SKILL.cursor.md"
                    if [[ -f "$cursor_override" ]]; then
                        output_content=$(cat "$cursor_override")
                        echo -e "    ${CYAN}(using SKILL.cursor.md override)${NC}"
                    else
                        local skill_name
                        skill_name=$(basename "$(dirname "$file")")
                        output_content=$(convert_skill_file "$source_content" "$skill_name")
                    fi
                else
                    output_content=$(update_tool_names "$source_content")
                    output_content=$(update_paths "$output_content")
                fi
            fi
        fi

        if $DIFF_MODE; then
            if [[ -f "$dest_path" ]]; then
                local existing
                existing=$(cat "$dest_path")
                if [[ "$output_content" != "$existing" ]]; then
                    echo -e "  ${YELLOW}CHANGED: $rel_path${NC}"
                    ((TOTAL_UPDATED++)) || true
                else
                    echo -e "  ${DIM}OK:      $rel_path${NC}"
                    ((TOTAL_SKIPPED++)) || true
                fi
            else
                echo -e "  ${GREEN}NEW:     $rel_path${NC}"
                ((TOTAL_CREATED++)) || true
            fi
            return 0 2>/dev/null || true
        fi

        if $DRY_RUN; then
            if [[ -f "$dest_path" ]]; then
                local existing
                existing=$(cat "$dest_path")
                if [[ "$output_content" != "$existing" ]]; then
                    echo -e "  ${YELLOW}WOULD UPDATE: $rel_path${NC}"
                    ((TOTAL_UPDATED++)) || true
                else
                    echo -e "  ${DIM}UP TO DATE:   $rel_path${NC}"
                    ((TOTAL_SKIPPED++)) || true
                fi
            else
                echo -e "  ${GREEN}WOULD CREATE: $rel_path${NC}"
                ((TOTAL_CREATED++)) || true
            fi
            return 0 2>/dev/null || true
        fi

        # Actual deploy
        local dest_dir
        dest_dir=$(dirname "$dest_path")
        mkdir -p "$dest_dir"

        if [[ -f "$dest_path" ]]; then
            local existing
            existing=$(cat "$dest_path")
            if [[ "$output_content" != "$existing" ]]; then
                printf '%s' "$output_content" > "$dest_path"
                echo -e "  ${YELLOW}UPDATED: $rel_path${NC}"
                ((TOTAL_UPDATED++)) || true
            else
                echo -e "  ${DIM}OK:      $rel_path${NC}"
                ((TOTAL_SKIPPED++)) || true
            fi
        else
            printf '%s' "$output_content" > "$dest_path"
            echo -e "  ${GREEN}CREATED: $rel_path${NC}"
            ((TOTAL_CREATED++)) || true
        fi
    done <<< "$files"
}

# --- Main ---

targets=()
[[ "$TARGET" == "all" || "$TARGET" == "claude" ]] && targets+=("claude-code")
[[ "$TARGET" == "all" || "$TARGET" == "cursor" ]] && targets+=("cursor")
[[ "$TARGET" == "all" || "$TARGET" == "wsl" ]] && targets+=("claude-code-wsl")

categories=()
[[ -z "$CATEGORY" || "$CATEGORY" == "agents" ]] && categories+=("agents")
[[ -z "$CATEGORY" || "$CATEGORY" == "skills" ]] && categories+=("skills")

if $DRY_RUN; then
    mode="DRY RUN"
elif $DIFF_MODE; then
    mode="DIFF"
else
    mode="DEPLOY"
fi

echo ""
echo -e "${CYAN}=== $mode ===${NC}"
echo "Targets:    ${targets[*]}"
echo "Categories: ${categories[*]}"
echo ""

if ! $DRY_RUN && ! $DIFF_MODE && ! $FORCE; then
    read -rp "Proceed? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

for t in "${targets[@]}"; do
    case "$t" in
        claude-code)     display_name="Claude Code" ;;
        claude-code-wsl) display_name="Claude Code (WSL)" ;;
        cursor)          display_name="Cursor" ;;
    esac
    if [[ "$t" == "claude-code-wsl" ]]; then
        wsl_check=$(jq -r ".\"$t\".agents.target" "$MANIFEST")
        wsl_base=$(dirname "$wsl_check")
        if ! test -d "$wsl_base"; then
            echo -e "  ${YELLOW}WSL target not accessible - skipping${NC}"
            continue
        fi
    fi
    echo -e "\n${MAGENTA}[$display_name]${NC}"

    for cat in "${categories[@]}"; do
        echo -e "  ${WHITE}$cat:${NC}"
        deploy_section "$t" "$cat"
    done
done

echo ""
echo -e "${CYAN}--- Summary ---${NC}"
if $DRY_RUN; then
    echo "Would create: $TOTAL_CREATED"
    echo "Would update: $TOTAL_UPDATED"
elif $DIFF_MODE; then
    echo "New:     $TOTAL_CREATED"
    echo "Changed: $TOTAL_UPDATED"
else
    echo "Created: $TOTAL_CREATED"
    echo "Updated: $TOTAL_UPDATED"
fi
echo "Up to date: $TOTAL_SKIPPED"
echo ""
