#!/bin/bash
# preserve-uncommitted-changes.sh
# Preserves all uncommitted git changes to a backup directory

set -e

BACKUP_DIR="${1:-/tmp/preserve-files}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🔄 Preserving uncommitted changes to: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Copy modified files (preserving directory structure)
echo "📝 Preserving modified files..."
git diff --name-only | while read file; do 
  if [ -f "$file" ]; then
    target="$BACKUP_DIR/$file"
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    echo "  ✅ Preserved: $file"
  fi
done

# Copy untracked files (preserving directory structure)
echo "📁 Preserving untracked files..."
git ls-files --others --exclude-standard | while read file; do 
  target="$BACKUP_DIR/$file"
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "  ✅ Preserved untracked: $file"
done

# Create summary
echo "📊 Creating backup summary..."
cat > "$BACKUP_DIR/BACKUP_SUMMARY.md" << EOF
# Git Changes Backup

**Created:** $(date)
**Git Branch:** $(git branch --show-current)
**Git Commit:** $(git rev-parse HEAD)

## Modified Files
\`\`\`
$(git diff --name-only)
\`\`\`

## Untracked Files
\`\`\`
$(git ls-files --others --exclude-standard)
\`\`\`

## Git Status
\`\`\`
$(git status --porcelain)
\`\`\`

## How to Restore
To restore these changes later:
\`\`\`bash
# Copy files back (be careful of conflicts)
cp -r $BACKUP_DIR/* .

# Or selectively restore specific files
cp $BACKUP_DIR/path/to/file path/to/file
\`\`\`
EOF

echo ""
echo "✅ Backup complete!"
echo "📁 Location: $BACKUP_DIR"
echo "📄 Summary: $BACKUP_DIR/BACKUP_SUMMARY.md"
echo ""
echo "💡 Usage:"
echo "   ./scripts/preserve-uncommitted-changes.sh [backup-directory]"
echo "   Default backup directory: /tmp/preserve-files"