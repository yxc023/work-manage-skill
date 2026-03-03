#!/bin/bash
# Work Manager - Update Task Progress
# Usage: 
#   work-update.sh "WORK_DIR" --analyze "task-description"
#   work-update.sh "WORK_DIR" --commit "task-description" "phase-name" "change-summary"
# Output: JSON

set -e

WORK_DIR="$1"
MODE="$2"

if [ -z "$WORK_DIR" ]; then
    echo '{"error": "Usage: work-update.sh WORK_DIR --analyze task-description"}'
    exit 1
fi

if [ "$MODE" = "--analyze" ]; then
    TASK_DESC="$3"
    
    if [ -z "$TASK_DESC" ]; then
        echo '{"error": "Task description is required"}'
        exit 1
    fi
    
    # Find task folder (fuzzy match)
    TASK_FOLDER=""
    ACTIVE_DIR="${WORK_DIR}/active"
    
    for dir in "$ACTIVE_DIR"/*; do
        if [ -d "$dir" ] && [[ "$(basename "$dir")" == *"${TASK_DESC}"* ]]; then
            TASK_FOLDER="$dir"
            break
        fi
    done
    
    if [ -z "$TASK_FOLDER" ] || [ ! -d "$TASK_FOLDER" ]; then
        echo "{\"error\": \"Task not found: ${TASK_DESC}\", \"available_tasks\": ["
        first=true
        for dir in "$ACTIVE_DIR"/*; do
            if [ -d "$dir" ]; then
                [ "$first" = true ] && first=false || echo ","
                echo -n "\"$(basename "$dir")\""
            fi
        done
        echo "]}"
        exit 1
    fi
    
    TASK_NAME=$(basename "$TASK_FOLDER")
    
    # Get git changes
    cd "$WORK_DIR"
    
    # Get last commit hash
    LAST_COMMIT=$(git log -1 --format=%H 2>/dev/null || echo "")
    
    if [ -z "$LAST_COMMIT" ]; then
        echo '{"error": "No commits found"}'
        exit 1
    fi
    
    # Get changed files (relative to work/)
    CHANGED_FILES=$(git diff --name-status "$LAST_COMMIT" -- "active/$TASK_NAME" | grep -v "^D" || true)
    
    # Read .gitignore to get ignore patterns
    GITIGNORE_PATH="$TASK_FOLDER/.gitignore"
    IGNORE_PATTERNS=("output/")
    if [ -f "$GITIGNORE_PATH" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && IGNORE_PATTERNS+=("$line")
        done < "$GITIGNORE_PATH"
    fi
    
    # Filter files
    CHANGED_JSON="[]"
    IGNORED_JSON="[]"
    
    # Build changed files JSON
    if [ -n "$CHANGED_FILES" ]; then
        CHANGED_JSON="["
        first=true
        while IFS= read -r line; do
            status="${line:0:1}"
            filepath=$(echo "${line:2}" | sed "s|${TASK_NAME}/||")
            
            # Check if should be ignored
            ignored=false
            for pattern in "${IGNORE_PATTERNS[@]}"; do
                if [[ "$filepath" == $pattern ]] || [[ "$filepath" == */$pattern ]]; then
                    ignored=true
                    break
                fi
            done
            
            if [ "$ignored" = true ]; then
                # Add to ignored
                IGNORED_JSON=$(echo "$IGNORED_JSON" | sed 's/\]$/,{"path": "'"$filepath"'", "status": "'"$status"'}]/')
                if [[ "$IGNORED_JSON" == "[]" ]]; then
                    IGNORED_JSON='[{"path": "'"$filepath"'", "status": "'"$status"'"}]'
                fi
            else
                # Add to changed
                if [ "$first" = true ]; then
                    CHANGED_JSON='[{"path": "'"$filepath"'", "status": "'"$status"'"}]'
                    first=false
                else
                    CHANGED_JSON="${CHANGED_JSON},{\"path\": \"$filepath\", \"status\": \"$status\"}"
                fi
            fi
        done <<< "$CHANGED_FILES"
        CHANGED_JSON="${CHANGED_JSON}]"
    fi
    
    # Check if WORK_LOG needs update (compare files in folder vs files listed)
    if [ -f "$WORK_LOG_PATH" ]; then
        # Get files in task folder (excluding output/, .gitignore, WORK_LOG.md)
        CURRENT_FILES=$(find "$TASK_FOLDER" -maxdepth 1 -type f ! -name ".gitignore" ! -name "WORK_LOG.md" ! -path "*/output/*" -exec basename {} \; 2>/dev/null || true)
        
        # Get files listed in WORK_LOG "任务文件" section
        WORK_LOG_FILES=$(sed -n '/## 任务文件/,/## 进展日志/p' "$WORK_LOG_PATH" 2>/dev/null | grep -E "^\- " | sed 's/^- //' || true)
        
        # Compare
        MISSING_JSON="["
        first=true
        for file in $CURRENT_FILES; do
            if ! echo "$WORK_LOG_FILES" | grep -q "$file"; then
                if [ "$first" = true ]; then
                    MISSING_JSON='["'"$file"'"'
                    first=false
                else
                    MISSING_JSON="${MISSING_JSON}, \"$file\""
                fi
            fi
        done
        MISSING_JSON="${MISSING_JSON}]"
        
        if [ "$MISSING_JSON" != "[]" ]; then
            NEEDS_UPDATE=true
            MISSING_FILES="$MISSING_JSON"
        fi
    fi
    
    # Output JSON
    cat << EOF
{
  "success": true,
  "task_folder": "${TASK_FOLDER}",
  "task_name": "${TASK_NAME}",
  "changed_files": ${CHANGED_JSON},
  "ignored_files": ${IGNORED_JSON},
  "readme_needs_update": ${NEEDS_UPDATE},
  "missing_files_in_readme": ${MISSING_FILES}
}
EOF

elif [ "$MODE" = "--commit" ]; then
    TASK_DESC="$3"
    CHANGE_SUMMARY="$4"
    
    if [ -z "$TASK_DESC" ] || [ -z "$CHANGE_SUMMARY" ]; then
        echo '{"error": "Usage: work-update.sh WORK_DIR --commit task-description change-summary"}'
        exit 1
    fi
    
    # Find task folder
    TASK_FOLDER=""
    ACTIVE_DIR="${WORK_DIR}/active"
    
    for dir in "$ACTIVE_DIR"/*; do
        if [ -d "$dir" ] && [[ "$(basename "$dir")" == *"${TASK_DESC}"* ]]; then
            TASK_FOLDER="$dir"
            break
        fi
    done
    
    if [ -z "$TASK_FOLDER" ] || [ ! -d "$TASK_FOLDER" ]; then
        echo "{\"error\": \"Task not found: ${TASK_DESC}\"}"
        exit 1
    fi
    
    TASK_NAME=$(basename "$TASK_FOLDER")
    DATE_DISPLAY=$(date +%Y-%m-%d)
    WORK_LOG_PATH="$TASK_FOLDER/WORK_LOG.md"
    
    # Update WORK_LOG.md - append progress entry
    cat >> "$WORK_LOG_PATH" << EOF

### ${CHANGE_SUMMARY}
- 日期: ${DATE_DISPLAY}
- 描述: ${CHANGE_SUMMARY}
EOF

    # Auto-update 任务文件 section if needed
    # Get files in task folder (excluding output/, .gitignore, WORK_LOG.md)
    CURRENT_FILES=$(find "$TASK_FOLDER" -maxdepth 1 -type f ! -name ".gitignore" ! -name "WORK_LOG.md" ! -path "*/output/*" -exec basename {} \; 2>/dev/null || true)
    
    # Read current WORK_LOG content
    if [ -f "$WORK_LOG_PATH" ] && [ -n "$CURRENT_FILES" ]; then
        # Check if 任务文件 section has placeholder
        if grep -q "（自动列出" "$WORK_LOG_PATH"; then
            # Build new files list
            FILES_MARKDOWN=""
            for file in $CURRENT_FILES; do
                FILES_MARKDOWN="${FILES_MARKDOWN}- ${file}\n"
            done
            
            # Replace using awk
            awk '{if(/（自动列出/) {print ""; print "'"$FILES_MARKDOWN"'"} else {print}}' "$WORK_LOG_PATH" > "$WORK_LOG_PATH.tmp" && mv "$WORK_LOG_PATH.tmp" "$WORK_LOG_PATH"
        fi
    fi
    
    # Git commit
    cd "$WORK_DIR"
    git add "active/$TASK_NAME/WORK_LOG.md"
    
    # Add other tracked files
    for file in $CURRENT_FILES; do
        git add "active/$TASK_NAME/$file" 2>/dev/null || true
    done
    
    git commit -m "${TASK_DESC}: ${CHANGE_SUMMARY}" 2>/dev/null || echo "Nothing to commit"
    
    # Output JSON
    cat << EOF
{
  "success": true,
  "task_folder": "${TASK_FOLDER}",
  "message": "Task updated and committed"
}
EOF

else
    echo '{"error": "Invalid mode. Use --analyze or --commit"}'
    exit 1
fi
