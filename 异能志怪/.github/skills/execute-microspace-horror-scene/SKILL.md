---
name: execute-microspace-horror-scene
description: 'Use when: 微空间惊悚场景、楼道、电梯、值班室、出租屋、地下车库、医院走廊、办公室后区、狭窄空间、城市恐怖镜头、日常异化场景、都市志怪场景设计。常见说法：帮我写楼道这场、这个电梯场景怎么更吓人、把医院走廊写出压迫感、微空间惊悚怎么落地。'
argument-hint: '要处理哪个微空间场景？默认同时考虑现实针脚、反常细节、动作压力与场景内证据载体。'
---

# 执行城市微空间惊悚场景

## 保真迁移要求（强制）

命中微空间场景任务时，除读取本文件外，**必须继续读取**：

- [都市微空间惊悚保真规则](./references/migrated-microspace-scene-rules.md)

## 常见触发词 / 用户说法速查

- “楼道这场怎么写”
- “电梯场景怎么更吓人”
- “医院走廊这段太普通了”
- “值班室 / 地下车库 / 出租屋怎么做细思极恐”
- “帮我把日常空间写异化”

## 何时使用

当任务聚焦于**一个具体空间场景**，并需要把都市生活感与志怪惊悚感咬在一起时，加载并遵循本 Skill。

## 本 Skill 的核心任务

1. 先确定“空间常态”是什么。
2. 再放入一个足够小但足够反常的细节。
3. 让角色必须做选择，而不是只站着感到害怕。
4. 让反常最终能接回证据链、规则链或后续冲突，而不是只做气氛摆设。

## 执行顺序

1. 读取场景上下文，明确此处的现实功能：通行、值守、等候、居住、工作。
2. 选一种最合适的反常细节：声音、光线、气味、触感、位置偏差、时间错位。
3. 按“微反常升级梯子”确认异常不是一步到顶，而是沿 `可忽略 → 可怀疑 → 可确认 → 后果落地` 升级。
4. 增加角色动作和现场反馈，让惊悚通过“动作 → 后果”成立。
5. 用“证据载体菜单”确认场景里至少有一个可后续复盘的载体：回执、监控、灯控、门禁、病历、聊天记录、污渍、物件位置等。
6. 若场景压迫感始终立不起来，继续读取“感官与异化细节工具箱”与“空间类型速配表”。
7. 若动作和后果总是接不紧，继续读取“动作—后果速配表”与“动作失手升级清单”。
8. 若知道设计逻辑却落笔发涩，继续读取“微空间分型句库”与“章尾补针句库”。
9. 若场景开始发飘、发俗、发模板腔，继续读取“微空间场景禁忌清单”与“去模板腔清单”。
10. 若任务需要从零设计一个完整微空间场景，先填“微空间场景施工卡模板”。

## 必读参考

- [都市微空间惊悚保真规则](./references/migrated-microspace-scene-rules.md)
- [微空间场景模式](./references/microspace-scene-patterns.md)
- [微空间执行检查表](./references/microspace-scene-checklist.md)
- `references/microspace-abnormality-escalation-ladder.md`（微反常升级梯子）
- `references/microspace-evidence-carrier-menu.md`（微空间证据载体菜单）
- `references/microspace-action-consequence-matrix.md`（动作—后果速配表）
- `references/microspace-failed-action-escalation-list.md`（动作失手升级清单）
- `references/microspace-space-specific-line-bank.md`（微空间分型句库）
- `references/microspace-ending-needle-bank.md`（微空间章尾补针句库）
- `references/microspace-scene-anti-patterns.md`（微空间场景禁忌清单）
- `references/microspace-de-ai-checklist.md`（微空间去模板腔清单）
- [微空间场景施工卡模板](./references/microspace-scene-card-template.md)
- [感官与异化细节工具箱](./references/sensory-and-distortion-toolbox.md)
- [空间类型速配表](./references/space-type-usage-matrix.md)

## 与其他 Skill / Prompt 的边界

- 本 Skill 是场景技法模块，不替代整章控制卡或整章正文 prompt。
- 本 Skill 适合被 `prepare-chapter-control-card` 调用为单个场景单元的执行参考。

