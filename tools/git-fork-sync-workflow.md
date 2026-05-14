# Git Fork and Sync Workflow

## 1. Fork and Clone

```bash
# Fork via GitHub UI (click "Fork" button), then clone your fork
git clone https://github.com/YOUR_USERNAME/forked-repo.git
cd forked-repo

# Add the original repo as upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/original-repo.git
```

## 2. Make Changes in Your Fork

```bash
# Create a branch for your changes (recommended)
git checkout -b my-changes

# Edit files, then commit
git add path/to/changed-files
git commit -m "My custom changes"

# Push to your fork
git push origin my-changes
```

## 3. Sync from Original While Keeping Your Changes

```bash
# Fetch latest from original repo
git fetch upstream

# Option A: Rebase your changes on top of upstream (cleaner history)
git rebase upstream/main

# Option B: Merge upstream into your branch
git merge upstream/main

# If conflicts occur on your changed files, resolve them keeping your version:
git checkout --ours path/to/your-changed-file
git add path/to/your-changed-file
git rebase --continue  # or git merge --continue
```

### To Always Keep Specific Files Unchanged During Merges

Add a `.gitattributes` file:

```bash
echo "path/to/your-file merge=ours" >> .gitattributes
git config merge.ours.driver true
```

Or use a merge strategy:

```bash
git merge upstream/main -X ours  # Prefer your version on conflicts
```
