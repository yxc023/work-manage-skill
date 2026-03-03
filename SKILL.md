---
name: work-manager
description: Manage personal work workspace with tasks. Use when user invokes /work/new, /work/update, /work/archive, or /work/continue slash commands. Creates and manages task folders with date-based naming (YYYYMMDD-description) in work/active/ directory, maintains task tracking WORK_LOG files with progress logs, and handles git commits with change summaries.
---

# Work Manager

Manage personal work tasks with date-based organization, task tracking, and git integration.

## Workspace Structure

```
<current-directory>/
└── work/
    ├── active/           # Active tasks
    │   └── YYYYMMDD-task-name/
    │       ├── WORK_LOG.md    # Task tracking file
    │       ├── .gitignore   # Git ignore rules (filters output/)
    │       ├── output/      # Generated files (demo, analysis, etc.)
    │       └── ...         # Task files
    └── archive/          # Archived tasks
```

## Work Directory

The skill uses a `work` subdirectory in the current directory as its work directory.

**Auto-detect WORK_DIR:**
```bash
WORK_DIR="$PWD/work"
SKILL_DIR="<path-to>/.opencode/skills/work-manager"
```

## 文件存放规则

所有新生成的内容（页面、报告、临时文件、代码、文档等）都应优先写入 `output/` 文件夹，用户后续可根据需要将文件移出。

## Commands

### /work/new - Create New Task

**Usage:** `/work/new <task-description>`

**Steps:**
1. Get today's date in YYYYMMDD format
2. Create task folder: `work/active/YYYYMMDD-<task-description>/`
3. Create `output/` folder inside task folder
4. Create `.gitignore` file with content:
   ```
   output/
   ```
5. Create WORK_LOG.md with task tracking template
6. Initialize git repository in work/ if not already initialized
7. Initial commit (excluding output/ via .gitignore)
8. Return confirmation with task folder path

### Script: work-new.sh

```bash
WORK_DIR="$PWD/work"
SKILL_DIR="<path-to>/.opencode/skills/work-manager"
"$SKILL_DIR/scripts/work-new.sh" "$WORK_DIR" "task-description"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/active/20260302-xxx",
  "date": "2026-03-02",
  "message": "Task created successfully"
}
```

### /work/update - Update Task Progress

**Usage:** `/work/update <task-description> [phase-name]`

**Steps:**
1. Find task folder in `work/active/` matching `<task-description>`
2. If multiple matches, ask user to confirm which task
3. **Read .gitignore** in task folder to get ignore patterns
4. Get list of changed/new files since last commit: `git diff --name-status <last-commit>..HEAD -- <task-folder>/`
5. **Filter out ignored files:**
   - Parse .gitignore content
   - Exclude files matching ignore patterns (e.g., output/)
6. **Analyze remaining changes:**
   - For each changed file, show what was modified
   - Generate a clear summary of the changes
   - **DO NOT commit yet**
7. **Check if all current files are listed in WORK_LOG:**
   - Read WORK_LOG.md content
   - Get current list of files in task folder (excluding output/, .gitignore, WORK_LOG.md)
   - Parse "任务文件" section to extract listed files
   - Identify files NOT listed in WORK_LOG or missing descriptions
   - **If files are missing:**
     - Identify files NOT listed in WORK_LOG
     - Read the file content to understand its purpose
     - Generate appropriate description based on content:
       - If contains function/class definitions: "实现 X 功能的代码文件"
       - If contains config/setting: "配置文件"
       - If contains test cases: "测试文件"
       - If contains documentation: "文档文件"
       - If is a script: "脚本文件"
       - 根据文件中的具体内容给出更准确的描述
     - Update "任务文件" section in WORK_LOG with new file entries (只添加文件名和描述，不添加用户确认步骤)
8. **Present analysis to user and ask for confirmation** before proceeding
9. After user confirms, **Update WORK_LOG.md first:**
   - Append new progress entry:
     ```markdown
     ### 阶段 N: <phase-name>
     - 日期: YYYY-MM-DD
     - 描述: <change-summary>
     ```
   - Update task file list in "任务文件" section
10. **Then commit:**
    - Use `git add -A` but specify files explicitly to exclude ignored ones
    - Or use `git add <files>` with the filtered file list
    - Commit: `git commit -m "<task-description>: <phase-name> - <change-summary>"`
11. Return confirmation with commit info

**IMPORTANT:** 
- Always analyze changes BEFORE asking for confirmation
- Never auto-commit without user confirmation
- After user confirms, update WORK_LOG.md first, THEN commit
- Always filter out files listed in .gitignore
- **Always check if new files need to be added to WORK_LOG "任务文件" section with descriptions**

**Three-Phase Workflow (Script → LLM → Script):**

1. **Phase 1 - Script Analyze:** Run `--analyze` to get changed files, filter ignored files
2. **Phase 2 - LLM Process:** Analyze changes, generate summary, confirm with user
3. **Phase 3 - Script Commit:** Run `--commit` to update WORK_LOG and commit

**Change Summary Format:**
- List new files added
- List files modified
- Concise description of changes (first 100 chars per file)

### Script: work-update.sh

**Phase 1: Analyze**
```bash
"$SKILL_DIR/scripts/work-update.sh" "$WORK_DIR" --analyze "task-description"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/active/20260302-xxx",
  "changed_files": [{"path": "xxx.md", "status": "A"}],
  "ignored_files": [],
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
  "message": "Task updated and committed"
}
```

### /work/archive - Archive Task

**Usage:** `/work/archive <task-description>`

**Steps:**
1. Find task folder in `work/active/` matching `<task-description>`
2. Move task folder from `work/active/` to `work/archive/`
3. Update WORK_LOG.md status to "已归档"
4. Commit the move: `git add -A && git commit -m "archive: <task-description>"`
5. Return confirmation

### Script: work-archive.sh

```bash
"$SKILL_DIR/scripts/work-archive.sh" "$WORK_DIR" "task-description"
```

**Output:**
```json
{
  "success": true,
  "task_folder": "/path/to/work/archive/20260302-xxx",
  "message": "Task archived successfully"
}
```

### /work/continue - Continue Task

**Usage:** `/work/continue <task-description>`

Continue working on an existing task by reading its context.

**Steps:**
1. Find task folder in `work/active/` matching `<task-description>`
2. If multiple matches, ask user to confirm which task
3. **Read WORK_LOG.md** to understand task context:
   - Show task title and status
   - Show start date
   - Show progress history (all phases)
   - Show current phase number
4. List current task files (excluding output/ and .gitignore)
5. Present task summary to user:
   - Task status
   - What has been done (progress history)
   - Current file structure
   - Prompt: "Ready to continue. What would you like to do next?"

## Implementation Details

### Date Helper

Use shell command to get formatted date:
```bash
date +%Y%m%d    # For folder name: 20260227
date +%Y-%m-%d  # For WORK_LOG: 2026-02-27
```

### File Listing

For "任务文件" section, list all files in task folder (excluding WORK_LOG.md):
```bash
ls -la <task-folder> | grep -v WORK_LOG.md | awk '{print "- " $9}' | tail -n +4
```

### Git Integration

- Only commit to the work/ root repository (not per-task repos)
- Use meaningful commit messages combining task name and phase
- Extract change summary from `git diff --stat`

### Error Handling

- If work/active/ doesn't exist, create it
- If task folder not found, show available tasks in active/
- If already archived, notify user
- If not a git repository, initialize first
