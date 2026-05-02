---
name: 撰写小说章节SOP
description: '对单章或连续多章执行“创作→补字→润色→去AI味→审阅回炉→读者产物→摘要”的完整章节闭环；这是执行型 SOP，不是只产出计划或阶段汇报的规划型 Prompt，并默认路由到题材章节创作闭环 Skill。'
argument-hint: '给我 OUTLINE_FILE 与 CHAPTER_FILE；若是连续多章，可给 CHAPTER_FILES[] / OUTLINE_FILES[] / CHAPTER_BATCH[] / BATCH_ID。'
agent: 小说作者
---

# 撰写小说章节 SOP

## 题材技能路由（强制）

命中本 Prompt 时，必须先调用：`女频爱情-章节创作闭环`。

若当前批次章节已存在明确卷纲 / 章清单，默认应把 `女频爱情-生成章节控制卡` 视为正文施工前的上游必经层。

本入口不得把“只写初稿”冒充“完整章节 SOP”，也不得绕过题材链直接调用通用正文创作本体。

## 本 Prompt 只保留的职责

- 作为章节创作闭环的统一入口
- 保留默认正文目录、批量模式发现性、最小完成条件与最终摘要约束
- 把主体执行流程路由到 `女频爱情-章节创作闭环`

## 最小输入

- `OUTLINE_FILE`
- `CHAPTER_FILE`
- `RELATED_CONTEXT_FILES[]`（可选）
- `CHAPTER_FILES[] / OUTLINE_FILES[] / CHAPTER_BATCH[] / BATCH_ID`（批量模式可选）

## 最低执行要求

- 默认主对象是 `小说正文/` 下的原始章节正文，其它平台版本交给后续多平台链路处理。
- 批量模式必须逐章闭环，不得用整批口头概括替代逐章核验。
- 只有当正文、终审报告、阅读笔记、分章书评与日志全部闭环时，才允许宣称完成。
- 聊天侧最终只允许输出任务完成摘要，不得输出章节正文。

## 默认交付

- `CHAPTER_FILE`
- `REVIEW_REPORT_FILE`
- `READER_NOTE_FILE`
- `BOOK_REVIEW_FILE`
- 聊天侧最终只回任务完成摘要

## 一句话提醒

这份 Prompt 现在是**女频爱情入口层**；真正的章节创作 SOP、批量模式、日志机制与题材护栏，都必须继续到对应 `女频爱情-*` Skill 中读取并执行。
