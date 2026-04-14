---
description: "Use when creating, moving, reviewing, or reorganizing prompts, skills, agents, instructions, or other AI-writing assets inside a genre directory in this repository. Covers 题材目录内 `.github` 子目录的推荐布局、根 `.github` 与题材 `.github` 的职责边界，以及哪些内容应放在 `写作研究/`、`.github/prompts/`、`.github/skills/`、`.github/agents/`、`.github/instructions/`."
name: "题材目录内部资产布局规范"
---

# 题材目录内部资产布局规范

适用于本项目中**题材目录内部**的提示词、Skill、Agent、指令文件与研究资料的创建、迁移、整理和审阅。

## 默认布局

题材目录默认采用以下布局：

```text
题材名/
  写作研究/
  .github/
    prompts/
    skills/
    agents/
    instructions/
```

说明：

- `写作研究/` 放题材研究、平台调研、写作分析、外部资料整理等研究型内容
- `.github/prompts/` 放该题材专属 Prompt
- `.github/skills/` 放该题材专属 Skill
- `.github/agents/` 放该题材专属 Agent
- `.github/instructions/` 放仅对该题材目录有意义的局部指令

## 各目录的职责边界

### `写作研究/`

用于存放：

- 题材写作研究
- 平台风格研究
- 爽点、悬念、人物、结构等题材调查资料
- 供后续吸收进 Skill 的原始研究材料

不要把以下内容放进 `写作研究/`：

- 可直接执行的 Prompt
- 已固化完成的 Skill
- Agent 定义文件
- 本应作为局部规则生效的 instructions

### `.github/prompts/`

用于存放：

- 题材专属写作 Prompt
- 题材专属审阅 Prompt
- 题材专属平台输出 Prompt
- 题材专属 SOP Prompt

放入这里的前提是：该 Prompt 明显依赖该题材的表达目标、平台适配、审美预期或任务链路。

补充要求：

- 题材目录下的 Prompt 应优先作为**题材任务入口、薄编排层、兼容入口**使用。
- 若某项能力已经存在对应的题材 Skill 与通用 Skill 双层结构，则题材 Prompt **不应直接引用通用 Skill**，而应只引用对应题材 Skill，由题材 Skill 继续路由到通用 Skill。
- 因此，题材 Prompt 中不应直接写通用 Skill 名称列表、通用 Skill 路径，或通用 Skill 的 `references/` 文件路径。

### `.github/skills/`

用于存放：

- 题材专属 Skill
- 对通用 Skill 的题材包装层、路由层、兼容入口
- 该题材独有的规则、模板、检查清单、assets、references

补充要求：

- 若某项能力已经在 `通用skills/` 中沉淀为通用 Skill，则题材目录下对应 Skill 应作为该题材的默认发现入口与路由入口
- 该类题材 Skill 应显式要求加载、调用或组合调用对应通用 Skill，而不是只在题材目录中平行复制通用规则
- 题材 Skill 可以补充题材独有边界、题材文件组、题材禁行项与题材模板，但不应替代通用 Skill 的能力本体职责
- 当题材 Prompt 存在时，题材 Skill 还应承担**Prompt 的默认路由出口**职责：Prompt → 题材 Skill → 通用 Skill，而不是 Prompt → 通用 Skill

每个 Skill 应独立成目录，并以 `题材名-` 为前缀命名。

### `.github/agents/`

用于存放：

- 该题材专属的角色 Agent
- 该题材专属的审阅、创作、读者视角 Agent

只有当 Agent 明显带有该题材语境、任务目标或风格职责时，才放在题材目录下。

### `.github/instructions/`

用于存放：

- 仅对某个题材目录或该题材内部某类文件生效的局部指令
- 该题材独有的命名、结构、审阅、输出或迁移规则

如果规则适用于整个仓库，应优先放到根 `.github/instructions/` 或根 `AGENTS.md`，不要无谓下沉到题材目录。

## 根 `.github` 与题材目录 `.github` 的边界

### 根 `.github/`

适合放：

- 仓库级维护 Prompt
- 仓库级 instructions
- 面向整个项目的自动化编排入口
- 不属于某一个题材的仓库管理类 AI 资产

### `题材名/.github/`

适合放：

- 仅服务于该题材的 Prompt、Skill、Agent、局部 instructions
- 带有明确题材名、题材任务链路、题材审美口径的 AI 资产

### 边界原则

- **仓库级资产** 不要伪装成题材资产塞进某个题材目录
- **题材级资产** 不要混放到根 `.github/`
- 若一个能力可跨题材复用，优先先判断是否应沉淀为 `通用skills/` 中的通用 Skill

## 与 `通用skills/`、`scripts/`、`仅用于参考/` 的边界

- 跨题材复用的稳定能力 → `通用skills/`
- 不专属于某个 Skill 的通用脚本 → `scripts/`
- 非规范性、外部来源、与具体题材无关的参考内容 → `仅用于参考/`
- 明显属于某个题材任务链路的 Prompt / Skill / Agent / 局部指令 → 对应题材目录下的 `.github/`

## 新增资产时的推荐判断顺序

1. 先判断这是研究资料、Prompt、Skill、Agent、脚本，还是局部指令
2. 再判断它是仓库级、通用级，还是题材级
3. 若是题材级，再决定放到：
   - `写作研究/`
   - `.github/prompts/`
   - `.github/skills/`
   - `.github/agents/`
   - `.github/instructions/`
4. 最后检查命名是否为中文、前缀是否符合规则、边界是否清楚

## 不推荐做法

- 把题材研究文件塞进 `.github/prompts/` 或 `.github/skills/`
- 把题材 Prompt 混放到根 `.github/prompts/`
- 把跨题材通用能力做成某个题材目录下的专属 Skill
- 把仓库级规则下沉为多个题材目录里的重复 instructions
- 只因为目录里已有 `.github/` 就把所有内容都塞进去

## 推荐做法

- `写作研究/` 保持“研究材料池”定位
- `.github/prompts/`、`.github/skills/`、`.github/agents/` 承载题材可执行资产
- `.github/instructions/` 只写题材局部规则，不复制仓库级总规则
- 题材 Skill 优先与通用 Skill 形成“通用能力本体 + 题材包装层”关系
