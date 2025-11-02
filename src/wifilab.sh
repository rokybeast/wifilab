#!/bin/bash

SCRIPTS_DIR="scripts"

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "Error: No Scripts found, at: $SCRIPTS_DIR"
    exit 1
fi
echo "Available scripts:"
echo "------------------"

# Create array of script files
scripts=()
i=1
while IFS= read -r file; do
    if [ -x "$file" ]; then  # Check if file is executable
        scripts+=("$file")
        echo "$i) $(basename "$file")"
        ((i++))
    fi
done < <(find "$SCRIPTS_DIR" -type f)

if [ ${#scripts[@]} -eq 0 ]; then
    echo "No executable scripts found in $SCRIPTS_DIR"
    exit 1
fi

# Get user selection
echo
read -p "Select a script to run (1-${#scripts[@]}): " selection

# Validate input
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#scripts[@]} ]; then
    echo "Invalid selection"
    exit 1
fi

# Run selected script
selected_script="${scripts[$((selection-1))]}"
echo "Running: $(basename "$selected_script")"
"$selected_script"
