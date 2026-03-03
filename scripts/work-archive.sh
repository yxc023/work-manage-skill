#!/bin/bash
# Work Manager - Archive Task
# Usage: work-archive.sh "WORK_DIR" "task-description"
# Output: JSON

set -e

WORK_DIR="$1"

if [ -z "$WORK_DIR" ] || [ -z "$2" ]; then
    echo '{"error": "Usage: work-archive.sh WORK_DIR task-description"}'
    exit 1
fi

TASK_DESC="$2"
ACTIVE_DIR="${WORK_DIR}/active"
ARCHIVE_DIR="${WORK_DIR}/archive"

# Find task folder in active/
TASK_FOLDER=""
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
DATE_ARCHIVE=$(date +%Y-%m-%d)

# Check if already archived
if [ -d "${ARCHIVE_DIR}/${TASK_NAME}" ]; then
    echo "{\"error\": \"Task already archived: ${TASK_NAME}\"}"
    exit 1
fi

# Create archive dir if not exists
mkdir -p "$ARCHIVE_DIR"

# Move to archive
mv "$TASK_FOLDER" "${ARCHIVE_DIR}/${TASK_NAME}"

# Update WORK_LOG.md status and archive date
WORK_LOG_PATH="${ARCHIVE_DIR}/${TASK_NAME}/WORK_LOG.md"
if [ -f "$WORK_LOG_PATH" ]; then
    sed -i '' 's/- 状态: 进行中/- 状态: 已归档/' "$WORK_LOG_PATH"
    # Add archive date after 开始日期 line
    awk '{print} /^- 开始日期: / {print "- 归档日期: '"$DATE_ARCHIVE"'"}' "$WORK_LOG_PATH" > "$WORK_LOG_PATH.tmp" && mv "$WORK_LOG_PATH.tmp" "$WORK_LOG_PATH"
fi

# Git commit
cd "$WORK_DIR"
git add -A
git commit -m "archive: ${TASK_DESC}" 2>/dev/null || echo "Nothing to commit"

# Output JSON
cat << EOF
{
  "success": true,
  "task_folder": "${ARCHIVE_DIR}/${TASK_NAME}",
  "task_name": "${TASK_NAME}",
  "message": "Task archived successfully"
}
EOF
