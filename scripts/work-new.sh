#!/bin/bash
# Work Manager - Create New Task
# Usage: work-new.sh "WORK_DIR" "task-description"
# Output: JSON

set -e

WORK_DIR="$1"

if [ -z "$WORK_DIR" ] || [ -z "$2" ]; then
    echo '{"error": "Usage: work-new.sh WORK_DIR task-description"}'
    exit 1
fi

TASK_DESC="$2"
DATE_FOLDER=$(date +%Y%m%d)
DATE_DISPLAY=$(date +%Y-%m-%d)
FOLDER_NAME="${DATE_FOLDER}-${TASK_DESC}"
TASK_PATH="${WORK_DIR}/active/${FOLDER_NAME}"
OUTPUT_PATH="${TASK_PATH}/output"

# Create directories
mkdir -p "$OUTPUT_PATH"

# Create .gitignore
echo "output/" > "$TASK_PATH/.gitignore"

# Create WORK_LOG.md
cat > "$TASK_PATH/WORK_LOG.md" << EOF
# ${TASK_DESC}

- 开始日期: ${DATE_DISPLAY}
- 状态: 进行中

## 任务文件

- output/ - AI 生成信息的暂存区（审核后移出）
- 其他文件...

## 进展日志

### 初始
- 日期: ${DATE_DISPLAY}
- 描述: 任务创建

> 注意：此文件仅用于任务跟踪，不在此写具体工作内容。
EOF

# Check if already under git
cd "$WORK_DIR"
if [ ! -d ".git" ]; then
    echo '{"error": "Work directory is not a git repository. Please run: cd WORK_DIR && git init"}'
    exit 1
fi

# Create .gitignore if not exists (only ignore output/)
if [ ! -f ".gitignore" ]; then
    echo "output/" > .gitignore
fi

# Initial commit
git add -A
git commit -m "init: ${TASK_DESC}" 2>/dev/null || echo '{"warning": "Nothing to commit"}'

# Output JSON
cat << EOF
{
  "success": true,
  "task_folder": "${TASK_PATH}",
  "relative_path": "work/active/${FOLDER_NAME}",
  "date": "${DATE_DISPLAY}",
  "message": "Task created successfully"
}
EOF
