# sync-from-upstream.sh

Keep your fork synchronized with the original Microsoft repository.

## Overview

This script downloads the latest changes from the original `microsoft/intune-my-macs` repository and merges them into your local fork. If there are conflicts (same file changed in both places), you'll be guided through choosing which version to keep.

## Quick Start

```bash
cd ~/your-fork-name
./tools/sync-from-upstream.sh
```

## What It Does

1. **Detects your fork** - Auto-detects from git config, asks you to confirm
2. **Checks for local changes** - Finds any uncommitted work
3. **Downloads from original** - Fetches latest from Microsoft's repo
4. **Shows differences** - Lists new, deleted, and modified files
5. **Merges changes** - Combines original repo updates with your fork
6. **Resolves conflicts** - Interactive prompts if same file changed in both places
7. **Pushes to GitHub** - Optionally uploads merged changes to your fork

## Step-by-Step Walkthrough

### Step 1: Fork Detection

```
[INFO] Detected your fork: https://github.com/YourUsername/your-fork-name.git

Is this correct? (Y/n): 
```

- Press **Enter** to accept
- Type **n** to enter a different URL

### Step 2: Local Changes Check

If you have uncommitted work, you'll see:

```
Modified files (you changed these):
  📝 SECURITY.md

New files (exist locally but not in git):
  ➕ my-new-file.md

Options:
  1) Commit changes now    - Your changes are KEPT permanently, then sync adds changes from original repo (upstream)
  2) Set aside temporarily - Your changes are KEPT but hidden during sync, restored after
  3) Abort sync            - Your changes are KEPT, nothing from original repo (upstream) is downloaded
```

| Option | What Happens | When to Use |
|--------|--------------|-------------|
| **1** | Saves your changes, then syncs | You want to keep your changes permanently |
| **2** | Hides your changes, syncs, then restores them | You're not ready to commit yet |
| **3** | Cancels everything | You want to review your changes first |

**All options preserve your work** - nothing is deleted.

### Step 3: Differences Preview

```
New files from original repo (will be added to your fork):
  ➕ new-feature.md

Files removed in original repo (may be deleted from your fork):
  ❌ deprecated-file.md

Files changed in original repo (may conflict with your changes):
  📝 README.md
```

### Step 4: Merge

If there are no conflicts, the merge happens automatically.

If conflicts exist, you'll be prompted for each conflicting file:

```
==========================================
[FILE] Conflict in: SECURITY.md
==========================================

Options:
  1) Keep YOUR version   - Discard changes from original, keep your local file
  2) Take ORIGINAL version - Replace your file with the one from original repo (upstream)
  3) Keep BOTH          - Leave for manual editing (conflict markers in file)
  4) Show full diff     - See both versions side by side
  5) Open in editor     - Edit the file manually
```

| Option | Result |
|--------|--------|
| **1** | Your file stays exactly as-is |
| **2** | Microsoft's version replaces yours |
| **3** | File has both versions with markers for you to edit later |
| **4** | Shows content of both versions |
| **5** | Opens the file in your editor to manually merge |

### Step 5: Push to Fork

```
[STEP] Push changes to your GitHub fork?
[INFO] You have 2 new commit(s) ready to upload to your fork

Your fork: https://github.com/YourUsername/your-fork-name.git

Push to your fork? (y/N): 
```

- Type **y** to upload changes to GitHub
- Press **Enter** to keep changes local only

## Requirements

- **git** - Must be installed
- **Run from inside your fork** - The script must be run from your cloned directory

## Common Issues

### "Not inside a git repository!"

You ran the script from the wrong directory. Change to your cloned fork first:

```bash
cd ~/your-fork-name
./tools/sync-from-upstream.sh
```

### Merge conflicts

Use the interactive prompts to choose which version to keep. Option 4 (Show full diff) helps you see what changed in each version.

### Changes not appearing on GitHub

After the merge, you need to push. Either:
- Type **y** when prompted "Push to your fork?"
- Or run manually: `git push`

## Git Terminology

| Term | Meaning |
|------|---------|
| **origin** | Your fork on GitHub |
| **upstream** | The original Microsoft repository |
| **fetch** | Download changes (doesn't apply them) |
| **merge** | Combine downloaded changes with your files |
| **push** | Upload your local changes to GitHub |
| **stash** | Temporarily hide uncommitted changes |
