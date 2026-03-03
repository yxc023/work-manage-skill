---
name: work-manager
description: Manage personal work workspace with tasks. Use when user invokes /work/new, /work/update, /work/archive, or /work/continue slash commands. Creates and manages task folders with date-based naming (YYYYMMDD-description) in work/active/ directory, maintains task tracking WORK_LOG files with progress logs, and handles git commits with change summaries.
---

# Work Manager

管理个人工作任务的工具，支持日期组织、任务跟踪和 git 集成。

## 目录结构

```
work/
├── active/           # 活跃任务
│   └── YYYYMMDD-task-name/
│       ├── WORK_LOG.md  # 工作日志
│       ├── .gitignore   # 忽略 output/
│       ├── output/      # 新生成内容放这里
│       └── ...         # 具体工作文件
└── archive/          # 已归档任务
```

## Work Directory

**Auto-detect:**
```bash
WORK_DIR="$PWD/work"
SKILL_DIR="<path-to>/.opencode/skills/work-manager"
```

---

## /work/new - 创建任务

创建新任务文件夹。

**执行脚本:**
```bash
"$SKILL_DIR/scripts/work-new.sh" "$WORK_DIR" "任务描述"
```
→ 创建任务文件夹、WORK_LOG.md、output/、.gitignore，自动提交

---

## /work/update - 更新任务进度

三阶段流程：**脚本分析 → 大模型处理 → 脚本提交**

### Phase 1: 脚本分析

执行脚本获取变更：
```bash
"$SKILL_DIR/scripts/work-update.sh" "$WORK_DIR" --analyze "任务描述"
```
→ 返回 changed_files, ignored_files, missing_files_in_readme

### Phase 2: 大模型处理

根据脚本输出：
1. 分析变更内容
2. 检查 WORK_LOG.md 是否需要更新文件列表
3. 生成变更摘要
4. 向用户确认

### Phase 3: 脚本提交

用户确认后执行：
```bash
"$SKILL_DIR/scripts/work-update.sh" "$WORK_DIR" --commit "任务描述" "变更摘要"
```
→ 更新 WORK_LOG.md，提交变更

**IMPORTANT:**
- 必须先分析再确认，确认后才能提交
- 始终过滤 .gitignore 中的文件
- 检查新文件是否需要添加到 WORK_LOG.md "任务文件" 区域

---

## /work/archive - 归档任务

归档任务到 archive 目录。

**执行脚本:**
```bash
"$SKILL_DIR/scripts/work-archive.sh" "$WORK_DIR" "任务描述"
```
→ 移动任务到 archive/，更新状态为"已归档"，添加归档日期，自动提交

---

## /work/continue - 继续任务

读取任务上下文，继续工作。

**步骤:**
1. 查找任务文件夹
2. 读取 WORK_LOG.md
3. 展示: 任务状态、开始日期、进展历史、当前文件结构
4. 提示: "Ready to continue. What would you like to do next?"

---

## WORK_LOG.md 模板

```markdown
# 任务名称

- 开始日期: YYYY-MM-DD
- 状态: 进行中

## 任务文件

- output/ - AI 生成信息的暂存区（审核后移出）
- 其他文件...

## 进展日志

### 初始
- 日期: YYYY-MM-DD
- 描述: 任务创建

> 注意：此文件仅用于任务跟踪，不在此写具体工作内容。
```
