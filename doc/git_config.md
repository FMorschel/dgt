# Git Configuration for Gerrit Integration

This document describes the Git configuration format used by DGT to track Gerrit metadata for branches.

## Overview

When you upload a change to Gerrit using tools like `git-cl`, `repo upload`, or similar Gerrit upload utilities, they store metadata about the upload in your local Git configuration file (`.git/config`). DGT reads this metadata to efficiently query Gerrit for change status.

## Configuration Format

Git config stores Gerrit metadata in the `[branch "branch-name"]` section using custom keys:

```ini
[branch "my-feature-branch"]
    remote = origin
    merge = refs/heads/main
    gerritissue = 389423
    gerritserver = https://dart-review.googlesource.com
    gerritpatchset = 3
    gerritsquashhash = abc123def456789...
    last-upload-hash = def456abc789012...
```

## Gerrit-specific Configuration Keys

### `gerritissue`

**Type:** Integer (stored as string)  
**Example:** `389423`

The Gerrit change number assigned when the change was first uploaded. This is the primary identifier used by DGT to query the Gerrit API.

**Usage in DGT:**

- Used to construct the API endpoint: `/changes/{gerritissue}`
- Preferred over Change-ID for queries (more efficient)

### `gerritserver`

**Type:** URL  
**Example:** `https://dart-review.googlesource.com`

The Gerrit server URL where the change was uploaded.

**Usage in DGT:**

- Used to construct the full API URL
- Allows support for different Gerrit instances
- Defaults to `https://dart-review.googlesource.com` if not specified

### `gerritpatchset`

**Type:** Integer (stored as string)  
**Example:** `3`

The current patchset number for this branch. Each time you amend and re-upload a change, the patchset number increments.

**Usage in DGT:**

- Currently informational (not used in queries)
- Future enhancement: Could be used to detect when local changes differ from uploaded version

### `gerritsquashhash`

**Type:** Git commit hash (SHA-1)  
**Example:** `abc123def456789012345678901234567890abcd`

The hash of the squashed commit as it appears in Gerrit. Gerrit typically squashes all commits in a branch into a single commit for review.

**Usage in DGT:**

- Currently informational (not actively used)
- Future enhancement: Could be compared with `current_revision` from API

### `last-upload-hash`

**Type:** Git commit hash (SHA-1)  
**Example:** `def456abc789012345678901234567890abcdef`

The hash of the last commit that was uploaded to Gerrit from this branch.

**Usage in DGT:**

- Currently informational (not actively used)
- Future enhancement: Could be compared with local hash to detect un-uploaded changes

## How DGT Uses Git Config

### 1. Branch Discovery

DGT first gets all local branches using:

```bash
git branch --list
```

### 2. Config Reading

For each branch, DGT reads the Gerrit config using:

```bash
git config --get branch.<branch-name>.gerritissue
git config --get branch.<branch-name>.gerritserver
git config --get branch.<branch-name>.gerritpatchset
git config --get branch.<branch-name>.gerritsquashhash
git config --get branch.<branch-name>.last-upload-hash
```

### 3. API Query Decision

**If `gerritissue` and `gerritserver` are present:**

- DGT queries Gerrit API using the issue number
- This is the most efficient method

**If Gerrit config is missing:**

- DGT attempts to extract Change-ID from the commit message
- Queries Gerrit using the Change-ID (slower, less reliable)
- If no Change-ID found, displays "-" for Gerrit columns

## Example Git Config File

Here's what a typical `.git/config` file might look like for a repository with multiple branches:

```ini
[core]
    repositoryformatversion = 0
    filemode = true
    bare = false

[remote "origin"]
    url = https://dart.googlesource.com/sdk
    fetch = +refs/heads/*:refs/remotes/origin/*

[branch "main"]
    remote = origin
    merge = refs/heads/main

[branch "feature/new-api"]
    remote = origin
    merge = refs/heads/main
    gerritissue = 389423
    gerritserver = https://dart-review.googlesource.com
    gerritpatchset = 3
    gerritsquashhash = abc123def456789012345678901234567890abcd
    last-upload-hash = def456abc789012345678901234567890abcdef

[branch "bugfix/memory-leak"]
    remote = origin
    merge = refs/heads/main
    gerritissue = 389424
    gerritserver = https://dart-review.googlesource.com
    gerritpatchset = 1
    gerritsquashhash = 123abc456def789012345678901234567890abcd
    last-upload-hash = 456def789abc012345678901234567890abcdef

[branch "local-experiment"]
    remote = origin
    merge = refs/heads/main
    # No Gerrit config - this branch hasn't been uploaded
```

## Checking Your Git Config

You can view your Git config with:

```bash
# View entire config
git config --list

# View config for a specific branch
git config --get-regexp 'branch\.feature/new-api\..*'

# View just the Gerrit issue number
git config --get branch.feature/new-api.gerritissue
```

## Manually Setting Gerrit Config

While upload tools typically set this automatically, you can manually configure it:

```bash
git config branch.my-branch.gerritissue 389423
git config branch.my-branch.gerritserver https://dart-review.googlesource.com
git config branch.my-branch.gerritpatchset 1
```

**Warning:** Manual configuration should only be done if you know what you're doing. Incorrect values will cause DGT to display incorrect information.

## Config Persistence

Git config is stored in `.git/config`, which is:

- **Local to your repository** (not tracked by Git)
- **Not shared** with other developers
- **Preserved** across checkouts and branch switches
- **Lost** if you delete and re-clone the repository

This means each developer has their own Gerrit metadata for their local branches.

## Troubleshooting

### "Branch shows '-' for Gerrit status but I uploaded it"

**Possible causes:**

1. The upload tool didn't write config (check `.git/config`)
2. You uploaded from a different local branch name
3. You cloned the repo after uploading (config is local)

**Solution:** Check if config exists:

```bash
git config --get branch.<your-branch>.gerritissue
```

### "DGT shows wrong change information"

**Possible causes:**

1. Stale config from a previous upload
2. Branch was reset or rebased after upload
3. Config was manually edited incorrectly

**Solution:** Re-upload the change or manually fix the config values.

## Future Enhancements

Potential future uses of Git config data:

- **Detect un-uploaded changes:** Compare `last-upload-hash` with current hash
- **Show patchset information:** Display current vs. uploaded patchset
- **Smart sync detection:** Warn when local differs from Gerrit
- **Auto-update config:** Update config when querying Gerrit API

## References

- [Git Config Documentation](https://git-scm.com/docs/git-config)
- [Gerrit Upload Tools](https://gerrit-review.googlesource.com/Documentation/user-upload.html)
- [git-cl Documentation](https://chromium.googlesource.com/chromium/tools/depot_tools/+/main/README.git-cl.md)
