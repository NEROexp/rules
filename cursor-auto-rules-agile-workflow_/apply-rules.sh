#!/bin/bash

# Check if target directory is provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide the target project directory"
    echo "Usage: ./apply-rules.sh <target-project-directory>"
    exit 1
fi

TARGET_DIR="$1"

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating new project directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    
    # Initialize readme for new project
    cat > "$TARGET_DIR/README.md" << 'EOL'
# New Project

This project has been initialized with agile workflow support and auto rule generation configured from [cursor-auto-rules-agile-workflow](https://github.com/bmadcode/cursor-auto-rules-agile-workflow).

For workflow documentation, see [Workflow Rules](docs/workflow-rules.md).
EOL
fi

# Create .cursor directory if it doesn't exist
mkdir -p "$TARGET_DIR/.cursor"

# Function to copy files only if they don't exist in target
copy_if_not_exists() {
    local src="$1"
    local dest="$2"
    
    if [ ! -e "$dest" ]; then
        echo "📦 Copying new file: $(basename "$dest")"
        cp "$src" "$dest"
    else
        echo "⏭️  Skipping existing file: $(basename "$dest")"
    fi
}

# Copy all files from .cursor directory structure
echo "📦 Copying .cursor directory files..."
find .cursor -type f | while read -r file; do
    # Get the relative path from .cursor
    rel_path="${file#.cursor/}"
    target_file="$TARGET_DIR/.cursor/$rel_path"
    target_dir="$(dirname "$target_file")"
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Copy file if it doesn't exist
    copy_if_not_exists "$file" "$target_file"
done

# Create docs directory if it doesn't exist
mkdir -p "$TARGET_DIR/docs"

# Create workflow documentation
cat > "$TARGET_DIR/docs/workflow-rules.md" << 'EOL'
# Cursor Workflow Rules

This project has been updated to use the auto rule generator from [cursor-auto-rules-agile-workflow](https://github.com/bmadcode/cursor-auto-rules-agile-workflow).

> **Note**: This script can be safely re-run at any time to update the template rules to their latest versions. It will not impact or overwrite any custom rules you've created.

## Core Features

- Automated rule generation
- Standardized documentation formats
- Supports all 4 Note Types automatically
- AI behavior control and optimization
- Flexible workflow integration options

## Getting Started

1. Review the templates in \`xnotes/\`
2. Choose your preferred workflow approach
3. Start using the AI with confidence!

For demos and tutorials, visit: [BMad Code Videos](https://youtube.com/bmadcode)
EOL

# Update .gitignore if needed
if [ -f "$TARGET_DIR/.gitignore" ]; then
    if ! grep -q "\.cursor/rules/_\*\.mdc" "$TARGET_DIR/.gitignore"; then
        echo -e "\n# Private individual user cursor rules\n.cursor/rules/_*.mdc" >> "$TARGET_DIR/.gitignore"
    fi
else
    echo -e "# Private individual user cursor rules\n.cursor/rules/_*.mdc" > "$TARGET_DIR/.gitignore"
fi

# Create xnotes directory and copy files
echo "📝 Setting up samples xnotes..."
mkdir -p "$TARGET_DIR/xnotes"
cp -r xnotes/* "$TARGET_DIR/xnotes/"

# Update .cursorignore if needed
if [ -f "$TARGET_DIR/.cursorignore" ]; then
    if ! grep -q "^xnotes/" "$TARGET_DIR/.cursorignore"; then
        echo -e "\n# Project notes and templates\nxnotes/" >> "$TARGET_DIR/.cursorignore"
    fi
else
    echo -e "# Project notes and templates\nxnotes/" > "$TARGET_DIR/.cursorignore"
fi

# Create or update .cursorindexingignore
if [ -f "$TARGET_DIR/.cursorindexingignore" ]; then
    # Backup the original file before modifying
    cp "$TARGET_DIR/.cursorindexingignore" "$TARGET_DIR/.cursorindexingignore.bak"
    
    # Copy all entries from the source .cursorindexingignore to the target
    cp ".cursorindexingignore" "$TARGET_DIR/.cursorindexingignore"
    
    echo "🔄 Updated .cursorindexingignore with all entries from source"
else
    # Create new file by copying the current one
    cp ".cursorindexingignore" "$TARGET_DIR/.cursorindexingignore"
    echo "📝 Created new .cursorindexingignore file"
fi

echo "✨ Deployment Complete!"
echo "📁 Core rule generator: $TARGET_DIR/.cursor/rules/core-rules/rule-generating-agent.mdc"
echo "📁 Sample subfolders and rules: $TARGET_DIR/.cursor/rules/{sub-folders}/"
echo "📁 Sample Agile Workflow Templates: $TARGET_DIR/.cursor/templates/"
echo "📄 Workflow Documentation: $TARGET_DIR/docs/workflow-rules.md"
echo "🔒 Updated .gitignore, .cursorignore, and .cursorindexingignore"
