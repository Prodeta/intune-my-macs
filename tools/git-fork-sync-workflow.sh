#!/bin/bash
#
# git-fork-sync-workflow.sh - Fork and Clone Script for intune-my-macs
# 
# Original: https://github.com/microsoft/intune-my-macs.git
# Fork:     Specified by user at runtime
#

set -e

# Configuration - Original repo (fixed)
ORIGINAL_OWNER="microsoft"
ORIGINAL_REPO="intune-my-macs"
ORIGINAL_URL="https://github.com/${ORIGINAL_OWNER}/${ORIGINAL_REPO}.git"

# Fork configuration - Set by user input
FORK_OWNER=""
FORK_REPO=""
FORK_URL=""
CLONE_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get fork information from user
get_fork_info() {
    echo ""
    echo "This script will clone YOUR fork of the original Microsoft repository."
    echo ""
    echo "Original repo: ${ORIGINAL_URL}"
    echo ""
    echo "Please enter your fork URL."
    echo "Example: https://github.com/YourUsername/intune-my-macs.git"
    echo "         https://github.com/YourOrg/my-custom-fork-name.git"
    echo ""
    
    while true; do
        read -p "Your fork URL: " FORK_URL
        
        # Validate URL format
        if [[ "$FORK_URL" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
            FORK_OWNER="${BASH_REMATCH[1]}"
            FORK_REPO="${BASH_REMATCH[2]}"
            # Remove .git suffix if present
            FORK_REPO="${FORK_REPO%.git}"
            # Ensure URL ends with .git
            FORK_URL="https://github.com/${FORK_OWNER}/${FORK_REPO}.git"
            CLONE_DIR="${HOME}/${FORK_REPO}"
            
            echo ""
            echo_info "Fork owner: ${FORK_OWNER}"
            echo_info "Fork repo:  ${FORK_REPO}"
            echo_info "Clone to:   ${CLONE_DIR}"
            echo ""
            
            read -p "Is this correct? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                break
            fi
            echo ""
        else
            echo_error "Invalid GitHub URL format."
            echo "Please enter a URL like: https://github.com/YourUsername/repo-name.git"
            echo ""
        fi
    done
}

# Check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        echo_error "git is not installed. Please install git first."
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        echo_warn "GitHub CLI (gh) is not installed."
        echo_warn "You can install it with: brew install gh"
        echo_warn "Proceeding without automatic fork creation..."
        GH_AVAILABLE=false
    else
        GH_AVAILABLE=true
    fi
}

# Create fork using GitHub CLI (if needed)
create_fork() {
    if [ "$GH_AVAILABLE" = true ]; then
        echo_info "Checking GitHub CLI authentication..."
        if ! gh auth status &> /dev/null; then
            echo_warn "Not authenticated with GitHub CLI. Running 'gh auth login'..."
            gh auth login
        fi
        
        # Check if fork already exists
        echo_info "Verifying fork exists at ${FORK_OWNER}/${FORK_REPO}..."
        if gh repo view "${FORK_OWNER}/${FORK_REPO}" &> /dev/null; then
            echo_info "Fork ${FORK_OWNER}/${FORK_REPO} found!"
        else
            echo_warn "Fork ${FORK_OWNER}/${FORK_REPO} not found on GitHub."
            echo ""
            read -p "Would you like to create it now? (Y/n): " create_confirm
            if [[ ! "$create_confirm" =~ ^[Nn]$ ]]; then
                echo_info "Creating fork of ${ORIGINAL_OWNER}/${ORIGINAL_REPO}..."
                gh repo fork "${ORIGINAL_OWNER}/${ORIGINAL_REPO}" --fork-name "${FORK_REPO}" --clone=false
                echo_info "Fork created successfully!"
            else
                echo_error "Cannot proceed without a fork. Please create one first."
                exit 1
            fi
        fi
    else
        echo_warn "GitHub CLI not available - cannot verify fork exists."
        echo_warn "Make sure your fork exists at: ${FORK_URL}"
        echo ""
        read -p "Press Enter to continue (or Ctrl+C to abort)..."
    fi
}

# Clone the fork
clone_fork() {
    echo_info "Cloning fork to ${CLONE_DIR}..."
    
    if [ -d "$CLONE_DIR" ]; then
        echo_warn "Directory ${CLONE_DIR} already exists."
        read -p "Do you want to remove it and re-clone? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$CLONE_DIR"
        else
            echo_info "Skipping clone. Using existing directory."
            cd "$CLONE_DIR"
            return
        fi
    fi
    
    git clone "$FORK_URL" "$CLONE_DIR"
    cd "$CLONE_DIR"
    echo_info "Clone completed!"
}

# Setup upstream remote
setup_upstream() {
    echo_info "Setting up upstream remote..."
    
    # Check if upstream already exists
    if git remote | grep -q "upstream"; then
        echo_warn "Upstream remote already exists. Updating URL..."
        git remote set-url upstream "$ORIGINAL_URL"
    else
        git remote add upstream "$ORIGINAL_URL"
    fi
    
    echo_info "Upstream remote configured!"
    echo ""
    echo_info "Remote configuration:"
    git remote -v
}

# Fetch upstream
fetch_upstream() {
    echo_info "Fetching upstream branches..."
    git fetch upstream
    echo_info "Upstream branches fetched!"
}

# Summary
show_summary() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Setup Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Repository: ${CLONE_DIR}"
    echo ""
    echo "Remotes:"
    echo "  origin   -> ${FORK_URL} (your fork)"
    echo "  upstream -> ${ORIGINAL_URL} (original)"
    echo ""
    echo "Next steps:"
    echo "  1. Create a branch: git checkout -b my-changes"
    echo "  2. Make your changes and commit"
    echo "  3. Push to your fork: git push origin my-changes"
    echo ""
    echo "To sync with upstream:"
    echo "  git fetch upstream"
    echo "  git merge upstream/main  (or git rebase upstream/main)"
    echo ""
}

# Main
main() {
    echo "=========================================="
    echo "git-fork-sync-workflow.sh"
    echo "==========================================
    echo ""
    echo "Original repo: ${ORIGINAL_URL}"
    
    check_prerequisites
    get_fork_info
    create_fork
    clone_fork
    setup_upstream
    fetch_upstream
    show_summary
    
    # Change to the cloned directory and start a new shell
    echo_info "Opening a new shell in ${CLONE_DIR}..."
    cd "$CLONE_DIR" && exec $SHELL
}

main "$@"
