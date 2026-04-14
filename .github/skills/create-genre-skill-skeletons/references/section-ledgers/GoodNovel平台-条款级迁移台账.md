# GoodNovel 平台条款级迁移台账

## 适用源 Prompt

- `异能志怪/.github/prompts/输出GoodNovel版.prompt.md`
- `都市悬疑/.github/prompts/输出GoodNovel版.prompt.md`

## 台账

| 源文件 | 源章节/段落 | 信息类型 | 信息摘要 | 主落点类型 | 主落点文件 | 次级引用点 | 是否已迁移 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 两题材 | frontmatter 与入口名 | frontmatter | 保留 GoodNovel 入口名与触发词 | 薄 Prompt | 各自 Prompt | 对应题材 Skill | 部分 | 需后续 description 审计 |
| 两题材 | 迁移状态/当前状态说明 | 原地保留 | 当前薄入口压缩说明 | 原地保留 | 各自 Prompt | 总台账 | 是 | 已保留 |
| 两题材 | 0.任务定义 | 任务定义 | 面向 GoodNovel 的英文改写目标 | 通用 Skill | `通用skills/通用-输出GoodNovel版/SKILL.md` | 通用详细回填 refs | 是 | 已回填 |
| 两题材 | 0.1-0.3 | 继承关系/结构 | 基准继承、零新增、英文沉浸式体裁 | references | `通用skills/通用-输出GoodNovel版/references/分节级补救映射与详细规则回填.md` | SOP 英文平台总则 | 是 | 已回填 |
| 两题材 | 1.1 平台机制 | 平台共性 | 情绪黏性、关系张力、plain global English | references | 同上 | `平台共性执行细则.md` | 是 | 已回填 |
| 异能志怪 | 1.2 题材取舍 | 题材边界 | 规则代价、现实锚点、危险递进 | 题材 Skill | `异能志怪/.github/skills/异能志怪-输出GoodNovel版/references/分节级补救映射与详细规则回填.md` | 题材补丁 | 是 | 已回填 |
| 都市悬疑 | 1.2 题材取舍 | 题材边界 | 调查链、现实压迫、人物情绪代价 | 题材 Skill | `都市悬疑/.github/skills/都市悬疑-输出GoodNovel版/references/分节级补救映射与详细规则回填.md` | 题材补丁 | 是 | 已回填 |
| 两题材 | 2-4 | 路径/结构/语言门禁 | 输出目录、Len 下限、零中文、关系张力不脱轨 | references | 通用GoodNovel详细回填 refs | 薄 Prompt 兼容约束 | 是 | 已回填 |
| 两题材 | 5 | 执行前置 | emotional cliff、relationship tension、readable English | references | 通用GoodNovel详细回填 refs | SOP | 是 | 已回填 |
| 异能志怪 | 6 | 题材执行 | 情绪长在规则与代价上 | 题材 Skill | 异能志怪 GoodNovel 详细回填 refs | 题材补丁 | 是 | 已回填 |
| 都市悬疑 | 6 | 题材执行 | investigation + emotion 双推进 | 题材 Skill | 都市悬疑 GoodNovel 详细回填 refs | 题材补丁 | 是 | 已回填 |
| 两题材 | 7-8 | 输出/检查 | 情绪拉力、主线不断、英文自然 | references | 通用GoodNovel详细回填 refs | SOP 终检 | 是 | 已回填 |
