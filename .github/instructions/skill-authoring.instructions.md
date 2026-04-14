---
description: "Use when creating, editing, reviewing, renaming, migrating, or organizing SKILL.md files, skill folders, skill references, or reusable novel-writing capabilities in this repository. Covers 通用 Skill vs 题材 Skill placement, naming prefixes, Chinese naming, frontmatter, references, and how genre skills should route to common skills by name only."
name: "Skill 编写规范"
applyTo: "**/SKILL.md"
---

# Skill 编写规范

适用于本项目中所有 `SKILL.md` 的创建、修改、迁移、审阅与命名。

## 先判断能力归属

新增或改造 Skill 前，先判断该能力是：

- **通用能力**：与具体题材无关、可跨题材复用
- **题材专属能力**：明显依赖某个题材的叙事机制、表达重点或读者预期

判断完成后再决定落位，不要先建目录再补判断。

## 落位规则

- 通用能力放入 `通用skills/`
- 题材专属能力放入对应题材目录
- `scripts/` 只放通用脚本，不放 Skill
- `仅用于参考/` 只放外部参考内容，不放项目规范性 Skill
- 本项目是维护 Skill 的源项目，不把业务内容放在项目根 `.github/` 作为主要承载位置

## 命名规则

- `通用skills/` 下的 Skill 目录名与 Skill 名称都必须以 `通用-` 为前缀
- 题材目录下的 Skill 目录名与 Skill 名称都必须以 `题材名-` 为前缀
- Skill 目录名应与 frontmatter 中的 `name` 保持一致
- Skill、提示词、参考资料及相关目录名应优先使用中文
- 除工具链强制要求的固定文件名外，不额外引入英文命名

## SKILL.md 的最小结构

每个 Skill 应至少包含：

1. frontmatter
2. 一级标题（与 Skill 名称一致）
3. 适用场景 / 不适用场景
4. 核心任务或执行顺序
5. 关键边界与硬规则
6. 如有补充规范，明确要求继续读取哪些 `references/` 文件

## frontmatter 规范

- 必须有 `name`
- 必须有 `description`
- 建议有 `argument-hint`
- `description` 应清楚写出触发词、使用场景和收益
- `description` 与 `argument-hint` 优先使用中文

## references 组织规则

- Skill 的补充规则、检查清单、模板示例统一放在该 Skill 目录下的 `references/`
- `SKILL.md` 中如依赖额外规则，应明确写出必须继续读取的 `references/` 文件名
- 不要把关键执行规则只散落在参考文件里而不在 `SKILL.md` 做调度说明

## 通用 Skill 与题材 Skill 的关系

若某项能力已经沉淀为通用 Skill：

- 题材 Skill 应优先作为**题材包装层 / 路由层**
- 题材 Skill 负责保留题材名可发现性与入口兼容性
- 共性规则应维护在通用 Skill 中，不要在多个题材 Skill 中复制一套平行规则

若某项能力属于跨题材稳定复用的核心能力，还应同时满足以下**强制要求**：

- 应按“通用 Skill + 题材 Skill”双层结构建设，而不是只保留单一题材版实现
- 题材 Skill 必须明确对应到一个或多个通用 Skill，并承担题材用户的默认发现入口职责
- 题材 Skill 必须在 frontmatter `description` 或正文开头显式写出其对应的通用 Skill 名称
- 题材 Skill 的执行流程中必须明确要求先加载、继续读取、调用或组合调用对应的通用 Skill，不能只在 `references/` 中隐含提及
- 若某项核心能力暂时还没有对应通用 Skill，应优先补建通用 Skill，再保留题材 Skill 作为题材包装层
- 除题材特有边界、题材特有模板、题材特有禁行项外，不要把通用规则重新复制回题材 Skill 中平行维护

## 引用通用 Skill 的规则

在题材相关 Skill 中引用通用 Skill 时：

- 只使用通用 Skill 的名称进行引用
- 不使用相对路径
- 不使用绝对路径
- 不使用硬编码目录路径

可写成：

- `必须调用 通用-强化章末钩子`
- `继续读取 通用-生成章节控制卡`
- `先加载 通用-管理连续性冷热线，再执行题材补充规则`
- `组合调用 通用-生成章节控制卡 与 通用-管理连续性冷热线`

不要写成路径式引用。

其中：

- `必须调用` / `先加载` / `组合调用` 适用于强制流程
- `继续读取` 适用于必须补充阅读或执行的后续通用规则
- 不要把对应通用 Skill 写成“可选参考”或“有需要时再看”这类弱约束表述

## 题材目录下 Prompt 与通用 Skill 的关系

在各题材目录下的 `.github/prompts/*.prompt.md` 中：

- **不应直接引用通用 Skill**
- **不应直接写通用 Skill 的文件路径**
- **不应在 Prompt 中列出通用 Skill 的 `references/` 文件路径**

题材 Prompt 的正确做法是：

- 直接引用本题材对应的题材 Skill
- 由题材 Skill 再显式引用、加载、调用对应通用 Skill
- Prompt 自身只保留基准 Prompt、题材入口、最小兼容约束、执行顺序与迁移说明

换言之：

- **Prompt 负责入口与编排提醒**
- **题材 Skill 负责题材边界与通用 Skill 路由**
- **通用 Skill 负责跨题材平台共性本体**

不要在题材 Prompt 中把“题材 Skill + 通用 Skill”并列写成双入口，这会削弱题材 Skill 作为默认发现入口与路由层的职责。

## 编写与改造时的默认检查项

- 目录是否放对：通用 / 题材 / 参考 / 脚本
- Skill 名称、目录名、标题、frontmatter `name` 是否一致
- 前缀是否正确
- 是否优先沉淀为通用 Skill，而不是重复造题材平行 Skill
- 若是跨题材稳定复用的核心能力，是否已经形成“通用 Skill + 题材 Skill”双层对应关系
- 是否使用中文命名
- 是否把共性规则放回了通用 Skill
- 题材目录下的 `.prompt.md` 是否错误地直接引用了通用 Skill 或其路径
- 题材 Skill 引用通用 Skill 时是否只按名称引用
- 题材 Skill 是否在 `description` 或正文中显式声明了对应通用 Skill
- 题材 Skill 是否明确要求先加载、调用或组合调用对应通用 Skill，而不是只做弱提示
- `references/` 是否只放补充材料，关键调度是否已在 `SKILL.md` 说明

## 推荐做法

- 通用 Skill 写“能力本体”
- 题材 Skill 写“发现入口 + 路由规则 + 题材边界”
- 修改共性规则时，优先改通用 Skill，不在多个题材 Skill 分叉维护
