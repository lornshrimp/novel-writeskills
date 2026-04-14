---
name: 输出GoodNovel版
description: '将都市悬疑正文改写并落盘为更适合 GoodNovel 的英文连载版本。用于关系张力、情绪黏性、现实调查压力与英文平台追更动机并重的正文输出。关键词：GoodNovel版、都市悬疑、英文平台、关系张力。'
argument-hint: '例如：把这一章改成更适合 GoodNovel 的都市悬疑英文版本，并保留调查链与人物拉扯。'
agent: 小说作者
---
# 都市悬疑小说输出“GoodNovel版”统一提示词

## 迁移状态（硬性）

本 Prompt 已完成薄入口改造。命中本入口时，应把它视为题材入口与编排提醒，而不是平台规则的主承载文件。

## 0. 你的任务（一句话）

把输入章节改写为更适合 GoodNovel 的【都市悬疑】英文版本：保留核心信息、遵守英文门禁、输出到正确目录，并保持调查链、关系张力与追更拉力。

## 1. 必须同时读取并使用的文件（硬性）

### 1.1 基准 Prompt

- `.github/prompts/创建小说正文.prompt.md`
- `.github/prompts/正文润色.prompt.md`
- `.github/prompts/去AI味.prompt.md`

### 1.2 题材专属入口

- `.github/skills/都市悬疑-输出GoodNovel版/SKILL.md`
- `.github/skills/都市悬疑-输出GoodNovel版/references/题材边界与来源.md`
- `.github/skills/都市悬疑-输出GoodNovel版/references/执行细则与题材补丁.md`

## 2. 执行顺序（硬性）

1. 先读取并遵守基准 Prompt。
2. 再读取 `都市悬疑-输出GoodNovel版` 及其 references，并由该题材 Skill 继续路由到对应通用 Skill。
3. 先保调查链、现实压迫与零新增事实，再做英文情绪张力与关系拉力强化。
4. 最后才处理降相似度，不得为了降重破坏英文顺滑度与平台张力。

## 3. 本入口保留的最小兼容约束

- 输出目录根：`GoodNovel/`
- 输出文件只允许包含：英文标题、英文正文、`## 作者有话说`
- 正文 Len 不得低于 6500
- 除 `## 作者有话说` 这一行外，不得出现中文/CJK
- 不得把都市悬疑写成只有情绪、没有调查骨架的英文稿

## 4. 已迁移说明

平台共性、题材边界、执行补丁、标题细则、英文门禁、章内节拍与作者有话说口径，均已迁移到对应 Skill / references。若发生冲突，以“基准 Prompt + 题材 Skill”链路为准。
