# Duplicate File Cleanup Guide

Comprehensive guide for identifying and removing duplicate files across PhotoPrism, Nextcloud, and backup directories on FREDDY to reclaim disk space.

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Installation](#installation)
- [Usage](#usage)
- [Cleanup Strategies](#cleanup-strategies)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)

## Overview

The duplicate file finder scans PhotoPrism, Nextcloud, and backup directories to identify duplicate files based on MD5 checksums. It provides:

- **Accurate detection**: Uses file size + MD5 hash to identify true duplicates
- **Smart prioritization**: Keeps PhotoPrism originals, suggests deleting backups/copies
- **Safe cleanup**: Interactive mode with confirmation prompts
- **Dry run**: Preview what would be deleted before committing
- **Detailed reports**: Shows duplicate groups with size and location

### Directories Scanned

```bash
/mnt/photoprism/       # PhotoPrism storage (prioritize originals/)
/mnt/nextcloud/data/   # Nextcloud user data
/mnt/backup/freddy/    # Backup directory (exclude .sql.gz, .tar.gz)
```

## How It Works

### Detection Process

1. **Scan Phase**: Walks through directories, calculates MD5 hash for each file
2. **Analysis Phase**: Groups files by hash, identifies duplicates
3. **Report Phase**: Generates detailed report with:
   - Hash of duplicate content
   - File size
   - Number of copies
   - Wasted disk space
   - Location of each copy
4. **Cleanup Phase**: Interactive or automated deletion based on rules

### File Hash Format

```
hash|size|path|source
e4d909c290d0fb1ca068ffaddf22cbd0|5242880|/mnt/photoprism/originals/photo.jpg|photoprism
```

## Installation

### 1. Make Script Executable

```bash
cd /path/to/freddy
chmod +x scripts/find-duplicates.sh
```

### 2. Verify Dependencies

```bash
# Required: md5sum (part of coreutils)
which md5sum

# If missing, install:
sudo apt install coreutils  # Debian/Ubuntu
```

### 3. Create Report Directory

```bash
mkdir -p duplicate-reports
```

## Usage

### Basic Workflow

```bash
# 1. Scan for duplicates (takes time for large directories)
./scripts/find-duplicates.sh scan

# 2. Generate duplicate report
./scripts/find-duplicates.sh report

# 3. Preview what would be deleted
./scripts/find-duplicates.sh dry-run

# 4. Interactive cleanup
./scripts/find-duplicates.sh cleanup
```

### Command Reference

#### Scan

Scans all configured directories and generates file hash database.

```bash
./scripts/find-duplicates.sh scan
```

**Output:**
```
[12:34:56] Starting duplicate file scan...
[INFO] Scanning PhotoPrism directory: /mnt/photoprism
Scanned: 5000 files
[INFO] Scanning Nextcloud data directory: /mnt/nextcloud/data
Scanned: 10000 files
[INFO] Scanning backup directory: /mnt/backup/freddy
Scanned: 12000 files
[12:45:23] ✓ Scan complete: 12000 files scanned in 567s
[INFO] Results saved to: ./duplicate-reports/file-hashes.txt
```

#### Report

Analyzes scan results and generates duplicate report.

```bash
./scripts/find-duplicates.sh report
```

**Output:**
```
[12:50:00] Generating duplicate report...
[12:50:15] ✓ Report generated

[INFO] Full report: ./duplicate-reports/duplicates-20240115_125015.txt
[INFO] Summary:
===================================
SUMMARY
===================================
Total duplicate groups: 234
Total wasted space: 12.5 GB
```

**Report Format:**
```
===================================
Hash: e4d909c290d0fb1ca068ffaddf22cbd0
Size: 5 MB
Copies: 3
Wasted: 10 MB
Files:
  /mnt/photoprism/originals/2024/photo.jpg (photoprism)
  /mnt/nextcloud/data/user/files/Photos/photo.jpg (nextcloud)
  /mnt/backup/freddy/2024-01-10/photo.jpg (backup)
```

#### Dry Run

Simulates cleanup without deleting files.

```bash
./scripts/find-duplicates.sh dry-run
```

**Output:**
```
[13:00:00] Starting dry run (no files will be deleted)...
[INFO] Would keep: /mnt/photoprism/originals/2024/photo.jpg (PhotoPrism original)
[WARN] Would delete: /mnt/nextcloud/data/user/files/Photos/photo.jpg
[WARN] Would delete: /mnt/backup/freddy/2024-01-10/photo.jpg
[13:05:00] ✓ Dry run complete
[INFO] Would delete: 456 files
[INFO] Would free: 8500 MB
```

#### Cleanup

Interactive cleanup with per-group decisions.

```bash
./scripts/find-duplicates.sh cleanup
```

**Interactive Prompt:**
```
===================================
[INFO] Duplicate group found (3 copies):
  [1] /mnt/photoprism/originals/2024/photo.jpg (photoprism)
  [2] /mnt/nextcloud/data/user/files/Photos/photo.jpg (nextcloud)
  [3] /mnt/backup/freddy/2024-01-10/photo.jpg (backup)

Options:
  [1-3] Delete specific file
  [a] Auto-delete (keep PhotoPrism originals, delete backups/nextcloud)
  [s] Skip this group
  [q] Quit cleanup
Choice: 
```

## Cleanup Strategies

### Auto-Delete Rules

When you choose `[a]` auto-delete, the script applies these rules:

1. **Keep PhotoPrism originals**: Files in `/mnt/photoprism/originals/` are always kept
2. **Delete backups**: Files in `/mnt/backup/` are deleted if original exists
3. **Delete Nextcloud duplicates**: If file exists in PhotoPrism, delete from Nextcloud
4. **Keep first file**: If no PhotoPrism original, keep the first file found

### Manual Selection

Choose specific files to delete by number (`[1]`, `[2]`, etc.)

**Example:**
```
Choice: 2
[12:34:56] ✓ Deleted: /mnt/nextcloud/data/user/files/Photos/photo.jpg
```

### Recommended Strategy

```bash
# 1. Scan during low-activity period (takes time)
./scripts/find-duplicates.sh scan

# 2. Review report to understand duplicates
./scripts/find-duplicates.sh report
less duplicate-reports/duplicates-*.txt

# 3. Dry run to verify auto-delete behavior
./scripts/find-duplicates.sh dry-run > preview.txt
less preview.txt

# 4. Run cleanup with auto-delete for obvious duplicates
./scripts/find-duplicates.sh cleanup
# Choose [a] for most groups, [s] for uncertain ones

# 5. Re-run for manual review of skipped groups
./scripts/find-duplicates.sh cleanup
# Choose specific files for remaining duplicates
```

## Safety Features

### 1. Confirmation Prompts

```bash
⚠️  Interactive cleanup mode

This will go through each duplicate group and let you choose which files to delete.
Priority rules:
  1. Keep original files (PhotoPrism originals)
  2. Delete duplicates in backup directories
  3. Delete duplicates in Nextcloud if already in PhotoPrism

Continue? (y/N): 
```

### 2. File Verification

Script checks file existence before deletion:

```bash
if [[ -f "$path" ]]; then
    rm -f "$path"
    log "✓ Deleted: $path"
else
    warn "File not found: $path"
fi
```

### 3. Dry Run Mode

Always run `dry-run` before `cleanup` to verify:

```bash
./scripts/find-duplicates.sh dry-run > deletion-plan.txt
# Review deletion-plan.txt
./scripts/find-duplicates.sh cleanup
```

### 4. Scan Filters

Script only scans specific file types to avoid false positives:

**PhotoPrism/Backups:**
```bash
*.jpg, *.jpeg, *.png, *.gif, *.bmp, *.webp
*.mp4, *.mov, *.avi, *.mkv, *.heic, *.raw
```

**Nextcloud (additional):**
```bash
*.pdf, *.doc, *.docx, *.xls, *.xlsx
*.zip, *.tar, *.gz
```

**Excluded from backups:**
```bash
*.sql.gz  # Database dumps
*.tar.gz  # Archive backups
```

### 5. Priority Logic

Auto-delete respects this hierarchy:

1. **PhotoPrism originals** (`/mnt/photoprism/originals/`) → **Always keep**
2. **Nextcloud files** → Delete if duplicate exists in PhotoPrism
3. **Backup files** → Delete if original exists elsewhere
4. **PhotoPrism sidecar/cache** → Keep with original

## Troubleshooting

### Scan Takes Too Long

**Problem:** Scanning millions of files takes hours.

**Solutions:**

```bash
# Limit scan to specific directory
find /mnt/photoprism/originals -type f -iname "*.jpg" -print0 | \
    xargs -0 md5sum > custom-scan.txt

# Use nice/ionice to reduce system impact
nice -n 19 ionice -c3 ./scripts/find-duplicates.sh scan

# Run scan overnight or during low-activity period
echo "0 2 * * 0 cd /path/to/freddy && ./scripts/find-duplicates.sh scan" | crontab -
```

### False Positives

**Problem:** Different files reported as duplicates.

**Cause:** MD5 hash collision (extremely rare) or identical content.

**Solution:**

```bash
# Verify files are actually identical
md5sum /path/to/file1 /path/to/file2

# Compare file content
diff /path/to/file1 /path/to/file2

# If different, report bug (MD5 collision)
```

### Permission Denied

**Problem:** Can't read files in Nextcloud/PhotoPrism directories.

**Solution:**

```bash
# Run as user with read access
sudo -u www-data ./scripts/find-duplicates.sh scan

# Or adjust permissions
sudo chmod -R +r /mnt/nextcloud/data
```

### Out of Memory

**Problem:** Script crashes during scan on systems with limited RAM.

**Solution:**

```bash
# Process directories separately
PHOTOPRISM_DIR="/mnt/photoprism" ./scripts/find-duplicates.sh scan
NEXTCLOUD_DATA="/mnt/nextcloud/data" ./scripts/find-duplicates.sh scan

# Or use streaming approach with awk
find /mnt -type f -print0 | xargs -0 md5sum | \
    awk -F'  ' '{print $1 "|0|" $2 "|unknown"}' > file-hashes.txt
```

### Nextcloud Out of Sync

**Problem:** After deleting duplicates, Nextcloud shows missing files.

**Solution:**

```bash
# Rescan Nextcloud files
docker exec -u www-data nextcloud php occ files:scan --all

# Or rescan specific user
docker exec -u www-data nextcloud php occ files:scan user
```

### PhotoPrism Index Broken

**Problem:** PhotoPrism can't find photos after cleanup.

**Solution:**

```bash
# Re-index PhotoPrism
docker exec -it photoprism photoprism index --cleanup

# Or full re-index
docker exec -it photoprism photoprism index
```

## Best Practices

### 1. Regular Scans

Add to crontab for weekly scans:

```bash
# Run scan every Sunday at 2 AM
0 2 * * 0 cd /path/to/freddy && ./scripts/find-duplicates.sh scan

# Generate report after scan
0 3 * * 0 cd /path/to/freddy && ./scripts/find-duplicates.sh report
```

### 2. Backup Before Cleanup

```bash
# Create backup before major cleanup
./scripts/backup.sh

# Then run cleanup
./scripts/find-duplicates.sh cleanup
```

### 3. Review Reports

Always review reports before cleanup:

```bash
./scripts/find-duplicates.sh report
less duplicate-reports/duplicates-*.txt

# Look for unexpected patterns:
# - System files being flagged
# - Important documents in backup only
# - PhotoPrism originals with no other copy
```

### 4. Incremental Cleanup

Don't delete everything at once:

```bash
# Day 1: Delete obvious backup duplicates
./scripts/find-duplicates.sh cleanup  # Use [a] for backup files only

# Day 2: Review Nextcloud duplicates
./scripts/find-duplicates.sh cleanup  # Manual selection for Nextcloud

# Day 3: Review remaining edge cases
./scripts/find-duplicates.sh cleanup  # Careful manual review
```

### 5. Monitor Disk Space

```bash
# Before cleanup
df -h /mnt

# After cleanup
df -h /mnt

# Expected savings (from report)
grep "Total wasted space" duplicate-reports/summary-*.txt
```

## Integration with Backup System

### Exclude Duplicate Reports from Backups

Add to `.gitignore`:

```gitignore
# Duplicate reports
duplicate-reports/
*.txt
```

### Run Cleanup Before Backups

```bash
# In backup.sh, add before backup:
if [[ -x "$SCRIPT_DIR/find-duplicates.sh" ]]; then
    log "Running duplicate cleanup..."
    "$SCRIPT_DIR/find-duplicates.sh" scan
    "$SCRIPT_DIR/find-duplicates.sh" report
fi
```

## Advanced Usage

### Custom Scan Directories

Edit script to add/remove directories:

```bash
# In find-duplicates.sh
CUSTOM_DIR="/mnt/extra-storage"

if [[ -d "$CUSTOM_DIR" ]]; then
    info "Scanning custom directory: $CUSTOM_DIR"
    # ... scan logic ...
fi
```

### Filter by File Size

Only scan large files (>1MB) to save time:

```bash
find /mnt/photoprism -type f -size +1M -print0 | \
    xargs -0 md5sum > large-files-scan.txt
```

### Export to CSV

```bash
# Convert report to CSV for analysis
./scripts/find-duplicates.sh report
awk -F'|' 'NR>1 {print $1 "," $2 "," $3 "," $4}' \
    duplicate-reports/file-hashes.txt > duplicates.csv
```

## Summary

The duplicate file finder provides safe, intelligent cleanup of duplicate files across FREDDY storage systems:

- **Accurate**: MD5-based detection ensures true duplicates
- **Safe**: Interactive mode with dry-run preview
- **Smart**: Prioritizes PhotoPrism originals, suggests deleting copies
- **Comprehensive**: Scans PhotoPrism, Nextcloud, backups
- **Detailed**: Reports show size, location, wasted space

Run regularly to maintain optimal disk usage and prevent storage bloat.
