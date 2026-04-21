# Git Fork and Sync Scripts

These scripts help you manage a forked repository, making it easy to:
1. Create and clone a fork of the original repository
2. Keep your fork synchronized with the original

## Repository Configuration

| Repository | URL |
|------------|-----|
| **Original (Microsoft)** | https://github.com/microsoft/intune-my-macs.git |
| **Your Fork** | You specify this when running the script |

## Scripts Overview

### 1. git-fork-sync-workflow.sh

**Purpose:** One-time setup script to create a fork and clone it to your Mac.

**What it does:**
1. Checks that `git` is installed
2. Prompts you to enter your fork's URL
3. Verifies the fork exists on GitHub (if GitHub CLI is installed)
4. Clones your fork to your home directory
5. Sets up the connection to the original repo (for future syncing)
6. Opens a terminal in the cloned directory

**Usage:**
```bash
./tools/git-fork-sync-workflow.sh
```

You will be prompted to enter your fork URL:
```
Your fork URL: https://github.com/YourUsername/your-fork-name.git
```

**Prerequisites:**
- `git` (required)
- `gh` - GitHub CLI (optional, but recommended for automatic fork verification)
  - Install with: `brew install gh`

---

### 2. sync-from-upstream.sh

**Purpose:** Keeps your fork up-to-date with the original Microsoft repository.

**What it does:**
1. Auto-detects your fork from the local git configuration (asks you to confirm or change it)
2. Checks for local changes you haven't saved
3. Downloads the latest from the original repo
4. Shows what's different (new files, deleted files, changes)
5. Merges the changes into your fork
6. If conflicts occur, lets you choose which version to keep
7. Optionally pushes the merged changes to your GitHub fork

**Usage:**
```bash
cd ~/your-fork-name
./tools/sync-from-upstream.sh
```

You will see your detected fork and be asked to confirm:
```
[INFO] Detected your fork: https://github.com/YourUsername/your-fork-name.git

Is this correct? (Y/n): 
```

Press Enter to accept, or type `n` to enter a different URL.

> **Important:** Run this script from inside your cloned fork directory.

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INITIAL SETUP                                │
│                                                                      │
│   microsoft/intune-my-macs  ──fork──>  YourUsername/your-fork-name  │
│         (original)                           (your fork)             │
│                                                   │                  │
│                                                 clone                │
│                                                   ▼                  │
│                                            ~/your-fork-name         │
│                                            (your local copy)         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         ONGOING SYNC                                 │
│                                                                      │
│   microsoft/intune-my-macs                                          │
│         (original)                                                   │
│              │                                                       │
│            fetch  ◄── sync-from-upstream.sh                         │
│              ▼                                                       │
│      ~/your-fork-name  ──push──>  YourUsername/your-fork-name      │
│       (your local copy)                  (your fork on GitHub)       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Common Scenarios

### First-time setup
```bash
./tools/fork-and-clone.sh
# Enter your fork URL when prompted
```

### Sync your fork with the latest from Microsoft
```bash
cd ~/your-fork-name
./tools/sync-from-upstream.sh
```

### If you have local changes when syncing

The script will detect your changes and offer three options:

| Option | What Happens |
|--------|--------------|
| **1) Commit changes now** | Your changes are saved permanently, then sync adds changes from the original |
| **2) Set aside temporarily** | Your changes are hidden during sync, then restored after |
| **3) Abort sync** | Nothing happens, your changes remain as-is |

All options preserve your local work.

### If the same file was changed in both places

The script will ask you to choose for each conflicting file:

| Option | What Happens |
|--------|--------------|
| **1) Keep YOUR version** | Discard the original repo's changes, keep your file |
| **2) Take ORIGINAL version** | Replace your file with the one from Microsoft |
| **3) Keep BOTH** | Leave conflict markers in the file for manual editing |
| **4) Show full diff** | See both versions side by side |
| **5) Open in editor** | Edit the file manually to merge changes |

---

## Git Terminology Reference

| Term | Plain English | In This Workflow |
|------|---------------|------------------|
| **origin** | Where you cloned from | Your fork (CKunze-MSFT/intune-my-macs-ck) |
| **upstream** | The original source | Microsoft's repo (microsoft/intune-my-macs) |
| **fork** | Your copy of a repo | Your GitHub copy that you control |
| **clone** | Download to your Mac | The local folder on your computer |
| **fetch** | Download changes (don't apply) | Get latest from Microsoft |
| **merge** | Combine changes | Apply Microsoft's updates to your copy |
| **push** | Upload to GitHub | Send your local changes to your fork |
| **stash** | Temporarily hide changes | "Set aside" in the script |

---

## Troubleshooting

### "Not inside a git repository!"
Run the sync script from inside your cloned folder:
```bash
cd ~/your-fork-name
./tools/sync-from-upstream.sh
```

### "Invalid GitHub URL format"
Make sure you enter the full URL including `https://` and ending with `.git`:
```
https://github.com/YourUsername/your-fork-name.git
```

### GitHub CLI not authenticated
Run `gh auth login` and follow the prompts to sign in.

### Directory already exists
The fork-and-clone script will ask if you want to remove and re-clone.

### Merge conflicts
Use the interactive prompts to choose which version to keep for each file.
