---
name: work-manager
description: Manage personal work workspace with tasks. Use when user invokes /work/new, /work/update, /work/archive, or /work/continue slash commands. Creates and manages task folders with date-based naming (YYYYMMDD-description) in work/active/ directory, maintains task tracking WORK_LOG files with progress logs, and handles git commits with change summaries.
---

# Work Manager

Manage personal work tasks with date-based organization, task tracking, and git integration.

## Work Directory

The skill uses a `work` subdirectory in the current directory as its work directory.

**IMPORTANT:** Pass the absolute path to the `work` subdirectory (not the project root).

`WORK_DIR="/path/to/project/work"`

**Auto-detect WORK_DIR from current directory:**
```bash
# Get absolute path to current directory, then append /work
WORK_DIR="$(pwd)/work"
# Or if already in project root:
WORK_DIR="$(dirname "$PWD")/work"  # not applicable
# Better:
WORK_DIR="$PWD/work"
```

Example: if current directory is `/path/to/project`, use `WORK_DIR="/path/to/project/work"`

## Workspace Structure

```
<current-directory>/
└── work/
    ├── active/           # Active tasks
    │   └── YYYYMMDD-task-name/
    │       ├── WORK_LOG.md  # 工作日志 (任务跟踪，不写具体内容)
    │       ├── .gitignore   # Filters output/
    │       ├── output/      # 新生成内容优先放这里
    │       └── ...
    └── archive/          # Archived tasks
```

## 文件存放规则

**所有新生成的内容——无论是页面、分析报告、临时文件、代码还是文档——都应优先写入 `output/` 文件夹。**

用户后续可根据需要将文件从 `output/` 中移出。

---

## /work/new - Create New Task

**Usage:** `/work/new <task-description>`

### Steps

1. Get today's date: `YYYYMMDD` (folder), `YYYY-MM-DD` (日志)
2. Create folder: `work/active/YYYYMMDD-<task-description>/`
3. Create `output/` folder
4. Create `.gitignore` with content: `output/`
5. Create WORK_LOG.md from template (仅用于任务跟踪，不写具体工作内容)
6. **Verify work directory is under git** - if not, return error with instructions to run `git init`
7. Commit changes
8. Return task folder path

### Script: work-new.sh

```bash
# From project root (assuming work/ exists)
WORK_DIR="$PWD/work"
work-new.sh "$WORK_DIR" "task-description"
```

**Full Example:**
```bash
cd /path/to/project
WORK_DIR="$PWD/work"
"$SKILL_DIR/scripts/work-new.sh" "$WORK_DIR" "GitHub监控工具"
```

Where `SKILL_DIR="/path/to/.opencode/skills/work-manager"`

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/active/20260302-商圈经营分析",
  "relative_path": "work/active/20260302-商圈经营分析",
  "date": "2026-03-02",
  "message": "Task created successfully"
}
```

### WORK_LOG Template

```markdown
# <task-description>

- 开始日期: YYYY-MM-DD
- 状态: 进行中

## Output 文件夹

用于存放所有新生成的内容（页面、报告、临时文件、代码、文档等），后续可移出。

## 任务文件

（自动列出当前任务文件夹中的所有文件，排除 output/ 和 .gitignore）

## 进展日志

### 初始
- 日期: YYYY-MM-DD
- 描述: 任务创建

> 注意：此文件仅用于任务跟踪，不在此写具体工作内容。
```

---

## /work/update - Update Task Progress

**Usage:** `/work/update <task-description>`

### Steps

1. Find task folder in `work/active/` matching `<task-description>` (fuzzy match)
2. If multiple matches, ask user to confirm
3. **Analyze phase** (do NOT commit):
   - Read `.gitignore` for ignore patterns
   - Get changed files: `git diff --name-status <last-commit> -- active/<task-name>`
   - Filter out ignored files (e.g., output/)
   - Check if files in folder are listed in WORK_LOG "任务文件" section
4. Present analysis to user, ask for confirmation
5. After confirmation:
   - Update WORK_LOG.md: append progress entry (use change-summary directly as description), update file list
   - Commit: `git commit -m "<task>: <summary>"`
6. Return confirmation

### Script: work-update.sh

**Setup (run once):**
```bash
WORK_DIR="$PWD/work"
SKILL_DIR="/path/to/.opencode/skills/work-manager"
```

**Phase 1: Analyze**
```bash
"$SKILL_DIR/scripts/work-update.sh" "$WORK_DIR" --analyze "task-description"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/active/20260302-xxx",
  "task_name": "20260302-xxx",
  "changed_files": [{"path": "xxx.md", "status": "A"}],
  "ignored_files": [{"path": "output/demo.html", "status": "?"}],
  "readme_needs_update": true,
  "missing_files_in_readme": ["xxx.md"]
}
```

**Phase 2: Commit**
```bash
"$SKILL_DIR/scripts/work-update.sh" "$WORK_DIR" --commit "task-description" "change-summary"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/active/20260302-xxx",
  "message": "Task updated and committed"
}
```

---

## /work/archive - Archive Task

**Usage:** `/work/archive <task-description>`

### Steps

1. Find task folder in `work/active/` matching `<task-description>`
2. Move folder to `work/archive/`
3. Update WORK_LOG.md: change status to "已归档", add archive date
4. Commit: `git add -A && git commit -m "archive: <task>"`
5. Return confirmation

### Script: work-archive.sh

```bash
# Setup (run once)
WORK_DIR="$PWD/work"
SKILL_DIR="/path/to/.opencode/skills/work-manager"

# Archive
"$SKILL_DIR/scripts/work-archive.sh" "$WORK_DIR" "task-description"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/archive/20260302-商圈经营分析",
  "task_name": "20260302-商圈经营分析",
  "message": "Task archived successfully"
}
```

---

## /work/continue - Continue Task

**Usage:** `/work/continue <task-description>`

### Steps

1. Find task folder in `work/active/` matching `<task-description>`
2. If multiple matches, ask user to confirm
3. Read WORK_LOG.md to get:
   - Task title and status
   - Start date
   - Progress history (all phases)
   - Current phase number
4. List current task files (excluding output/, .gitignore)
5. Present summary with prompt: "Ready to continue. What would you like to do next?"
