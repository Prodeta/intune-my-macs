#!/bin/bash
#
# Sync from Upstream Script for intune-my-macs
# 
# This script fetches changes from the original repository and allows
# interactive conflict resolution when local changes conflict with upstream.
#
# Original: https://github.com/microsoft/intune-my-macs.git
# Fork:     Detected from your local git repository
#

set -e

# Configuration - Original repo (fixed)
ORIGINAL_URL="https://github.com/microsoft/intune-my-macs.git"
UPSTREAM_BRANCH="main"

# Fork URL - detected from local git config
FORK_URL=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
echo_file() { echo -e "${CYAN}[FILE]${NC} $1"; }

# Ensure we're in a git repository and get fork info
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo_error "Not inside a git repository!"
        echo_error "Please run this script from within your cloned fork directory."
        exit 1
    fi
    
    # Detect fork URL from origin remote
    detected_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -n "$detected_url" ]; then
        echo_info "Detected your fork: ${detected_url}"
        echo ""
        read -p "Is this correct? (Y/n): " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo ""
            read -p "Enter the correct fork URL: " FORK_URL
        else
            FORK_URL="$detected_url"
        fi
    else
        echo_warn "Could not auto-detect your fork URL."
        echo ""
        read -p "Enter your fork URL: " FORK_URL
    fi
    
    if [ -z "$FORK_URL" ]; then
        echo_error "Fork URL is required."
        exit 1
    fi
    
    echo_info "Your fork (origin): ${FORK_URL}"
}

# Setup upstream remote if not exists
ensure_upstream() {
    echo_step "Checking connection to original repo (upstream)..."
    
    if ! git remote | grep -q "upstream"; then
        echo_info "Adding link to original repo..."
        git remote add upstream "$ORIGINAL_URL"
    else
        # Verify the URL is correct
        current_url=$(git remote get-url upstream 2>/dev/null || echo "")
        if [ "$current_url" != "$ORIGINAL_URL" ]; then
            echo_warn "Updating original repo URL to $ORIGINAL_URL"
            git remote set-url upstream "$ORIGINAL_URL"
        fi
    fi
    
    echo_info "Original repo (upstream): $(git remote get-url upstream)"
}

# Check for uncommitted changes
check_local_changes() {
    echo_step "Checking for uncommitted changes..."
    
    if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo_warn "You have local changes that are not committed:"
        echo ""
        
        # Show modified files with clear descriptions
        modified=$(git diff --name-only 2>/dev/null)
        if [ -n "$modified" ]; then
            echo -e "${YELLOW}Modified files (you changed these):${NC}"
            echo "$modified" | while read file; do
                echo "  📝 $file"
            done
            echo ""
        fi
        
        # Show staged files
        staged=$(git diff --cached --name-only 2>/dev/null)
        if [ -n "$staged" ]; then
            echo -e "${GREEN}Staged files (ready to commit):${NC}"
            echo "$staged" | while read file; do
                echo "  ✅ $file"
            done
            echo ""
        fi
        
        # Show untracked files with clear description
        untracked=$(git ls-files --others --exclude-standard 2>/dev/null)
        if [ -n "$untracked" ]; then
            echo -e "${CYAN}New files (exist locally but not in git):${NC}"
            echo "$untracked" | while read file; do
                echo "  ➕ $file"
            done
            echo ""
        fi
        echo ""
        echo "Options:"
        echo "  1) Commit changes now    - Your changes are KEPT permanently, then sync adds changes from original repo (upstream)"
        echo "  2) Set aside temporarily - Your changes are KEPT but hidden during sync, restored after"
        echo "  3) Abort sync            - Your changes are KEPT, nothing from original repo (upstream) is downloaded"
        echo ""
        echo "Note: All options preserve your local changes. The difference is how they're handled during sync."
        echo ""
        read -p "Choose an option (1/2/3): " choice
        
        case $choice in
            1)
                read -p "Enter commit message: " commit_msg
                git add -A
                git commit -m "$commit_msg"
                echo_info "Changes committed."
                ;;
            2)
                git stash push -m "Pre-sync stash $(date +%Y%m%d-%H%M%S)"
                echo_info "Changes set aside. They will be restored after sync completes."
                STASHED=true
                ;;
            3)
                echo_info "Sync aborted."
                exit 0
                ;;
            *)
                echo_error "Invalid option. Aborting."
                exit 1
                ;;
        esac
    else
        echo_info "Working directory is clean."
    fi
}

# Fetch upstream changes
fetch_upstream() {
    echo_step "Fetching changes from original repo (upstream)..."
    git fetch upstream
    echo_info "Downloaded latest from original repo (upstream)."
}

# Show what's different between local and upstream
show_differences() {
    echo_step "Analyzing differences between your fork and the original repository..."
    echo ""
    
    local_branch=$(git branch --show-current)
    
    # Files only in upstream (new files from upstream)
    new_files=$(git diff --name-status "$local_branch" "upstream/$UPSTREAM_BRANCH" -- 2>/dev/null | grep "^A" || true)
    if [ -n "$new_files" ]; then
        echo -e "${GREEN}New files from original repo (will be added to your fork):${NC}"
        echo "$new_files" | while read status file; do
            echo "  ➕ $file"
        done
        echo ""
    fi
    
    # Files deleted in upstream
    deleted_files=$(git diff --name-status "$local_branch" "upstream/$UPSTREAM_BRANCH" -- 2>/dev/null | grep "^D" || true)
    if [ -n "$deleted_files" ]; then
        echo -e "${RED}Files removed in original repo (may be deleted from your fork):${NC}"
        echo "$deleted_files" | while read status file; do
            echo "  ❌ $file"
        done
        echo ""
    fi
    
    # Files modified in upstream
    modified_files=$(git diff --name-status "$local_branch" "upstream/$UPSTREAM_BRANCH" -- 2>/dev/null | grep "^M" || true)
    if [ -n "$modified_files" ]; then
        echo -e "${YELLOW}Files changed in original repo (may conflict with your changes):${NC}"
        echo "$modified_files" | while read status file; do
            echo "  📝 $file"
        done
        echo ""
    fi
    
    # Check if there are any differences
    if [ -z "$new_files" ] && [ -z "$deleted_files" ] && [ -z "$modified_files" ]; then
        echo_info "No differences found - your fork is up to date with the original!"
    fi
    echo ""
}

# Interactive merge with conflict resolution
interactive_merge() {
    echo_step "Starting interactive merge..."
    echo ""
    
    local_branch=$(git branch --show-current)
    
    # Attempt the merge
    if git merge "upstream/$UPSTREAM_BRANCH" --no-commit --no-ff 2>/dev/null; then
        # No conflicts - merge was clean
        if git diff --cached --quiet; then
            echo_info "Already up to date with the original repo (upstream)."
            git merge --abort 2>/dev/null || true
            return 0
        fi
        
        echo_info "Merge completed without conflicts."
        echo ""
        echo "Changed files:"
        git diff --cached --name-status
        echo ""
        read -p "Commit the merge? (Y/n): " confirm
        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            git commit -m "Merge upstream/$UPSTREAM_BRANCH into $local_branch"
            echo_info "Merge committed."
        else
            git merge --abort
            echo_warn "Merge aborted."
        fi
    else
        # There are conflicts
        echo_warn "Merge conflicts detected!"
        echo ""
        echo "These files have been changed in BOTH your fork AND the original repo."
        echo "You need to decide which version to keep for each file."
        echo ""
        
        # Get list of conflicted files
        conflicted_files=$(git diff --name-only --diff-filter=U)
        
        if [ -z "$conflicted_files" ]; then
            echo_info "No conflicts to resolve."
            return 0
        fi
        
        echo -e "${RED}Files with conflicts (need your decision):${NC}"
        echo "$conflicted_files" | while read file; do
            echo "  ⚠️  $file"
        done
        echo ""
        
        # Process each conflicted file
        echo "$conflicted_files" | while read file; do
            resolve_conflict "$file"
        done
        
        # Check if all conflicts are resolved
        remaining=$(git diff --name-only --diff-filter=U)
        if [ -z "$remaining" ]; then
            echo_info "All conflicts resolved!"
            echo ""
            read -p "Commit the merge? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                git commit -m "Merge upstream/$UPSTREAM_BRANCH into $local_branch (conflicts resolved)"
                echo_info "Merge committed."
            else
                git merge --abort
                echo_warn "Merge aborted. All changes reverted."
            fi
        else
            echo_warn "Some conflicts remain unresolved:"
            echo "$remaining"
            echo ""
            echo "You can:"
            echo "  1) Resolve manually and run: git add <file> && git commit"
            echo "  2) Abort the merge: git merge --abort"
        fi
    fi
}

# Resolve a single conflicted file
resolve_conflict() {
    local file="$1"
    
    echo ""
    echo "=========================================="
    echo_file "Conflict in: $file"
    echo "=========================================="
    echo ""
    
    # Show the diff
    echo "--- Differences ---"
    echo ""
    
    # Try to show a meaningful diff
    if [ -f "$file" ]; then
        # Show conflict markers if they exist
        if grep -q "<<<<<<< HEAD" "$file" 2>/dev/null; then
            echo "Conflict markers found in file:"
            echo ""
            grep -n -A3 -B1 "<<<<<<< HEAD\|=======\|>>>>>>>" "$file" | head -50
            echo ""
        else
            echo "File contents differ between versions."
        fi
    fi
    
    echo "Options:"
    echo "  1) Keep YOUR version   - Discard changes from original, keep your local file"
    echo "  2) Take ORIGINAL version - Replace your file with the one from original repo (upstream)"
    echo "  3) Keep BOTH          - Leave for manual editing (conflict markers in file)"
    echo "  4) Show full diff     - See both versions side by side"
    echo "  5) Open in editor     - Edit the file manually"
    echo ""
    
    while true; do
        read -p "Choose for '$file' (1/2/3/4/5): " choice
        
        case $choice in
            1)
                # Keep local version
                git checkout --ours "$file"
                git add "$file"
                echo_info "Kept YOUR version of $file"
                break
                ;;
            2)
                # Take upstream version
                git checkout --theirs "$file"
                git add "$file"
                echo_info "Took ORIGINAL REPO (UPSTREAM) version of $file"
                break
                ;;
            3)
                # Keep both - leave conflict markers for manual resolution
                echo_warn "File left with conflict markers for manual resolution."
                echo_warn "Edit the file, then run: git add $file"
                break
                ;;
            4)
                # Show full diff
                echo ""
                echo "=== YOUR VERSION (HEAD) ==="
                git show HEAD:"$file" 2>/dev/null | head -100 || echo "(file does not exist in your version)"
                echo ""
                echo "=== ORIGINAL REPO (UPSTREAM) VERSION ==="
                git show "upstream/$UPSTREAM_BRANCH":"$file" 2>/dev/null | head -100 || echo "(file does not exist in original repo)"
                echo ""
                ;;
            5)
                # Open in editor
                ${EDITOR:-vim} "$file"
                read -p "Mark as resolved? (y/N): " resolved
                if [[ "$resolved" =~ ^[Yy]$ ]]; then
                    git add "$file"
                    echo_info "Marked $file as resolved."
                    break
                fi
                ;;
            *)
                echo_error "Invalid option. Please choose 1, 2, 3, 4, or 5."
                ;;
        esac
    done
}

# Offer to push changes to fork
offer_push() {
    echo ""
    echo_step "Push changes to your GitHub fork?"
    
    local_branch=$(git branch --show-current)
    
    # Check if there are commits to push
    ahead=$(git rev-list --count "origin/$local_branch".."$local_branch" 2>/dev/null || echo "0")
    
    if [ "$ahead" -gt 0 ]; then
        echo_info "You have $ahead new commit(s) ready to upload to your fork"
        echo ""
        echo "Your fork: ${FORK_URL}"
        echo ""
        read -p "Push to your fork? (y/N): " push_confirm
        if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
            git push origin "$local_branch"
            echo_info "Changes pushed to your fork!"
        else
            echo_info "Changes kept local only. Run 'git push' later to upload to your fork."
        fi
    else
        echo_info "No new commits to push."
    fi
}

# Pop stash if we stashed earlier
restore_stash() {
    if [ "${STASHED:-false}" = true ]; then
        echo ""
        read -p "Restore your set-aside changes now? (Y/n): " restore
        if [[ ! "$restore" =~ ^[Nn]$ ]]; then
            git stash pop
            echo_info "Your changes have been restored."
        else
            echo_warn "Changes NOT restored. To restore later, run: git stash pop"
        fi
    fi
}

# Summary
show_summary() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Sync Complete!${NC}"
    echo "=========================================="
    echo ""
    
    local_branch=$(git branch --show-current)
    echo "Current branch: $local_branch"
    echo ""
    echo "Recent commits:"
    git log --oneline -5
    echo ""
}

# Main
main() {
    echo "=========================================="
    echo "Sync from Original Repo (Upstream)"
    echo "=========================================="
    echo ""
    echo "Original repo (upstream): $ORIGINAL_URL"
    echo ""
    
    STASHED=false
    
    check_git_repo
    ensure_upstream
    check_local_changes
    fetch_upstream
    show_differences
    
    read -p "Proceed with merge? (Y/n): " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        echo_info "Sync cancelled."
        restore_stash
        exit 0
    fi
    
    interactive_merge
    offer_push
    restore_stash
    show_summary
}

main "$@"
