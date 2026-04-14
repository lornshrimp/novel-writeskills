---
name: create-genre-skill-skeletons
description: 'Use when creating a full or partial set of genre wrapper skills under a genre directory. Builds `.github/skills/` subfolders and `SKILL.md` skeletons for a specified genre, keeps the `题材名-能力名` naming rule, and writes hard requirements that each genre skill must load and use its corresponding common skill when that common skill already exists.'
argument-hint: '题材目录名，以及要创建全量标准清单还是其中一部分。'
---

# 题材 Skill 骨架批量生成器

根据指定题材，在该题材目录下批量建立标准题材 Skill 的目录与 `SKILL.md` 骨架。

这个 Skill 的目标不是直接写厚内容，而是先把题材目录下的 **Skill 入口层 / 包装层 / 路由层** 批量立起来，并把“必须加载并使用对应通用 Skill”的硬要求写进每个骨架里。

## 继续读取的 references

- `references/standard-genre-skill-list.md`
- `references/genre-skill-skeleton-template.md`

## Use this skill when

- 你已经确定一个题材目录，想一次性补齐它的 `.github/skills/` 骨架
- 你要把通用 Skill 体系映射到某个题材目录下
- 你要建立一套标准化的题材 Skill 入口名，而不是逐个手工新建目录
- 你要确保题材 Skill 明确写出“必须加载并使用对应通用 Skill”的要求

## Do not use this skill when

- 你只想修改某一个现有 Skill 的局部正文
- 你要新建的是通用 Skill 本体，而不是题材包装层
- 你只想做一次性 Prompt，而不是可复用的题材 Skill 体系骨架

## 默认执行顺序

1. 确认目标题材目录是否存在；若不存在，先创建题材目录与 `.github/skills/` 目录。
2. 读取 `references/standard-genre-skill-list.md`，确定本次是创建全量清单，还是只创建一个子集。
3. 对每个目标能力判断对应的通用 Skill 状态：
   - 已存在通用 Skill
   - 暂无通用 Skill，仅能先建题材入口骨架
   - 需要组合调用多个通用 Skill
4. 依照“`题材名-` + 能力名”的命名规则创建目录。
5. 为每个目录写入 `SKILL.md` 骨架，至少包含：
   - frontmatter
   - 题材包装层定位
   - 对应通用 Skill
   - 题材补充职责
   - 强制要求与禁止事项
6. 同时为每个题材 Skill 目录创建 `references/` 占位目录，供后续补入题材专属规则、检查清单、模板与增补说明。
7. 若对应通用 Skill 已存在，则在骨架中明确写入：命中本技能时，**必须同时加载并使用**当前题材 Skill 与对应通用 Skill。
8. 若对应通用 Skill 尚未建立，则在骨架中明确写入：当前只保留题材入口骨架；后续应优先补建通用 Skill，并接入双层结构；在此之前不得在题材层扩写平行共性规则。
9. 复核命名、frontmatter、`references/` 占位目录、一致性与通用 Skill 路由要求。

## 决策规则

### 命名规则

- 题材 Skill 目录名默认通过把通用 Skill 名中的 `通用-` 替换为 `题材名-` 得到。
- 若某个题材已有历史入口名，允许保留该入口名，但正文中必须显式声明其对应的通用 Skill。
- 目录名、frontmatter `name` 与一级标题应保持一致。

### 通用 Skill 已存在时

- 题材 Skill 必须写成包装层 / 路由层 / 兼容入口。
- 必须显式写出对应通用 Skill 名称。
- 必须使用 `必须加载`、`必须调用`、`组合调用` 等强约束表述。
- 不要在题材骨架中复制通用 Skill 的完整共性规则。

### 通用 Skill 暂不存在时

- 允许先建立题材入口骨架，以保持题材 Skill 菜单结构完整。
- 骨架中必须写清“对应通用 Skill 待补建”。
- 骨架中必须写清：后续应优先补建通用 Skill，而不是直接在题材层长出一整套共性规则。
- 这类骨架默认只保留用途、题材补充方向、待接入说明与禁止事项。

### 组合调用场景

- 若某项题材能力需要组合多个通用 Skill，应在骨架中明确写出组合关系。
- 例如：连续性控制类题材 Skill 可以组合 `通用-生成章节控制卡` 与 `通用-管理连续性冷热线`。
- 例如：章节正文创作类题材 Skill 应以 `通用-创建小说正文` 为正文创作母入口，再按需组合 `通用-生成章节控制卡`、`通用-管理连续性冷热线`、`通用-执行场景单元`、`通用-强化章节开头`、`通用-强化章末钩子`、`通用-正文润色` 与 `通用-去AI味重写`。

## 输出要求

执行本 Skill 时，默认应产出：

- 新建的题材 Skill 目录列表
- 每个目录下的 `SKILL.md` 骨架
- 每个目录下的 `references/` 占位目录
- 每个骨架对应的通用 Skill 状态：已接入 / 待接入 / 组合接入
- 如有需要，附带“已创建 / 已存在 / 跳过”的结果汇总

## 强制要求

- 题材 Skill 必须以 `题材名-` 为前缀。
- 题材 Skill 目录默认同时创建 `references/` 占位目录。
- 已存在通用 Skill 的能力，题材骨架必须明确要求加载并使用对应通用 Skill。
- 暂无通用 Skill 的能力，题材骨架必须明确写出待接入说明，不得伪装成已完整落地。
- 引用通用 Skill 时只按名称引用，不写路径。
- 不得在题材骨架中恢复一整套平行共性规则。

## 完成检查

- 目录是否创建在正确的 `题材名/.github/skills/`
- 是否按目标清单建立了对应目录
- `SKILL.md` 是否具备最小结构
- `references/` 占位目录是否已一并创建
- 是否都写明了题材包装层定位
- 是否都写明了通用 Skill 的加载要求或待接入说明
- 是否存在命名不一致、前缀错误、路径式引用或弱约束表述
