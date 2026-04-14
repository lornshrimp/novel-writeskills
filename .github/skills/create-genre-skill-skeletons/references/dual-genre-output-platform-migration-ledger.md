# 双题材输出平台迁移总台账

本台账用于追踪 `异能志怪` 与 `都市悬疑` 两个题材目录下 `输出*.prompt.md` 的无损迁移状态。

## 说明

- `共享平台`：两个题材当前都已存在对应 Prompt，平台共性必须上收至同一个 `通用-输出*` Skill。
- `题材独有平台`：当前仅某一题材已存在对应 Prompt，通用 Skill 可先服务现有题材，后续其他题材复用。
- `源 Prompt 状态` 仅记录当前迁移进度，不代表可以删除原文件。
- 只有当“详细规则已完成无损映射 + 薄 Prompt / SOP 已接线”后，源 Prompt 才允许瘦身。

## 平台覆盖矩阵

| 平台 | 通用 Skill | 异能志怪 | 都市悬疑 | 平台类型 |
| --- | --- | --- | --- | --- |
| 番茄 | `通用-输出番茄版` | 有 | 有 | 共享平台 |
| 知乎 | `通用-输出知乎版` | 有 | 有 | 共享平台 |
| 豆瓣 | `通用-输出豆瓣版` | 有 | 有 | 共享平台 |
| 微信订阅号 | `通用-输出微信订阅号版` | 有 | 有 | 共享平台 |
| 出版社 | `通用-输出出版社版` | 有 | 有 | 共享平台 |
| WebNovel | `通用-输出WebNovel版` | 有 | 有 | 共享平台 |
| My Fiction | `通用-输出My Fiction版` | 有 | 有 | 共享平台 |
| GoodNovel | `通用-输出GoodNovel版` | 有 | 有 | 共享平台 |
| 七猫 | `通用-输出七猫版` | 有 | 无 | 题材独有平台 |
| 百度百家号 | `通用-输出百度百家号版` | 有 | 无 | 题材独有平台 |
| 小红书 | `通用-输出小红书版` | 有 | 无 | 题材独有平台 |
| B站 | `通用-输出B站版` | 有 | 无 | 题材独有平台 |
| 新浪微博 | `通用-输出新浪微博版` | 有 | 无 | 题材独有平台 |

## 当前迁移状态总表

| 源 Prompt | 目标通用 Skill | 目标题材 Skill | 当前状态 | 下一步 |
| --- | --- | --- | --- | --- |
| `异能志怪/.github/prompts/输出番茄版.prompt.md` | `通用-输出番茄版` | `异能志怪-输出番茄版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出知乎版.prompt.md` | `通用-输出知乎版` | `异能志怪-输出知乎版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出豆瓣版.prompt.md` | `通用-输出豆瓣版` | `异能志怪-输出豆瓣版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出微信订阅号版.prompt.md` | `通用-输出微信订阅号版` | `异能志怪-输出微信订阅号版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出出版社版.prompt.md` | `通用-输出出版社版` | `异能志怪-输出出版社版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出WebNovel版.prompt.md` | `通用-输出WebNovel版` | `异能志怪-输出WebNovel版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出My Fiction版.prompt.md` | `通用-输出My Fiction版` | `异能志怪-输出My Fiction版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出GoodNovel版.prompt.md` | `通用-输出GoodNovel版` | `异能志怪-输出GoodNovel版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `异能志怪/.github/prompts/输出七猫版.prompt.md` | `通用-输出七猫版` | `异能志怪-输出七猫版` | 已建映射并补回填 refs | 当前仅异能志怪覆盖；都市悬疑待补建 |
| `异能志怪/.github/prompts/输出百度百家号版.prompt.md` | `通用-输出百度百家号版` | `异能志怪-输出百度百家号版` | 已建映射并补回填 refs | 当前仅异能志怪覆盖；都市悬疑待补建 |
| `异能志怪/.github/prompts/输出小红书版.prompt.md` | `通用-输出小红书版` | `异能志怪-输出小红书版` | 已建映射并补回填 refs | 当前仅异能志怪覆盖；都市悬疑待补建 |
| `异能志怪/.github/prompts/输出B站版.prompt.md` | `通用-输出B站版` | `异能志怪-输出B站版` | 已建映射并补回填 refs | 当前仅异能志怪覆盖；都市悬疑待补建 |
| `异能志怪/.github/prompts/输出新浪微博版.prompt.md` | `通用-输出新浪微博版` | `异能志怪-输出新浪微博版` | 已建映射并补回填 refs | 当前仅异能志怪覆盖；都市悬疑待补建 |
| `都市悬疑/.github/prompts/输出番茄版.prompt.md` | `通用-输出番茄版` | `都市悬疑-输出番茄版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出知乎版.prompt.md` | `通用-输出知乎版` | `都市悬疑-输出知乎版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出豆瓣版.prompt.md` | `通用-输出豆瓣版` | `都市悬疑-输出豆瓣版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出微信订阅号版.prompt.md` | `通用-输出微信订阅号版` | `都市悬疑-输出微信订阅号版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出出版社版.prompt.md` | `通用-输出出版社版` | `都市悬疑-输出出版社版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出WebNovel版.prompt.md` | `通用-输出WebNovel版` | `都市悬疑-输出WebNovel版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出My Fiction版.prompt.md` | `通用-输出My Fiction版` | `都市悬疑-输出My Fiction版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |
| `都市悬疑/.github/prompts/输出GoodNovel版.prompt.md` | `通用-输出GoodNovel版` | `都市悬疑-输出GoodNovel版` | 已建映射并补回填 refs | 继续审计 frontmatter 触发词与 SOP 精确引用 |

## 当前已完成事项

- 已更新标准题材 Skill 清单，纳入输出平台 Skill family。
- 已建立无损迁移台账模板与审计清单。
- 已建立 13 个 `通用-输出*` Skill 骨架。
- 已建立 `异能志怪` 当前 13 个 `输出*` 对应的题材包装 Skill 骨架。
- 已建立 `都市悬疑` 当前 8 个 `输出*` 对应的题材包装 Skill 骨架。
- 已为 13 个平台建立条款级迁移台账，并将主落点回填到通用 / 题材详细 refs。

## 本台账后续更新原则

- 每完成一个源 Prompt 的分节映射，就应把对应行的“当前状态”从“已建骨架”更新为“已建映射”。
- 每完成一个源 Prompt 的薄入口改造，就应把对应行的“当前状态”更新为“已改薄 Prompt”。
- 每完成一个平台在对应 SOP 中的接线，就应在备注中补记“已接 SOP”。
- 只有当某行同时满足“已建映射 + 已改薄 Prompt + 已接 SOP”时，才可考虑进入“允许删除重复正文”的审查阶段。
