# WebNovel 平台条款级迁移台账

## 适用源 Prompt

- `异能志怪/.github/prompts/输出WebNovel版.prompt.md`
- `都市悬疑/.github/prompts/输出WebNovel版.prompt.md`

## 台账

| 源文件 | 源章节/段落 | 信息类型 | 信息摘要 | 主落点类型 | 主落点文件 | 次级引用点 | 是否已迁移 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 两题材 | frontmatter 与入口名 | frontmatter | 保留 WebNovel 入口名与触发词 | 薄 Prompt | 各自 Prompt | 对应题材 Skill | 部分 | 仍需 description 关键词严校 |
| 两题材 | 迁移状态/当前状态说明 | 原地保留 | 当前非无损完成的过渡说明 | 原地保留 | 各自 Prompt | 总台账 | 是 | 已保留 |
| 两题材 | 0.任务定义 | 任务定义 | 面向 WebNovel 的英文版本改写目标 | 通用 Skill | `通用skills/通用-输出WebNovel版/SKILL.md` | 通用详细回填 refs | 是 | 已回填 |
| 两题材 | 0.1-0.3 | 继承关系/语言门禁 | 基准继承、零新增、沉浸式英文小说、零中文/CJK | references | `通用skills/通用-输出WebNovel版/references/分节级补救映射与详细规则回填.md` | SOP 英文平台门禁 | 是 | 已回填 |
| 两题材 | 1.1 平台机制/输出语言 | 平台共性 | global English、跨文化可读性、hook-driven 节奏 | references | 同上 | `平台共性执行细则.md` | 是 | 已回填 |
| 异能志怪 | 1.2 题材取舍 | 题材边界 | 规则机制、功能表达、文化特异性可读化 | 题材 Skill | `异能志怪/.github/skills/异能志怪-输出WebNovel版/references/分节级补救映射与详细规则回填.md` | 题材补丁 | 是 | 已回填 |
| 都市悬疑 | 1.2 题材取舍 | 题材边界 | 调查链、公平推理、现实程序的国际化表达 | 题材 Skill | `都市悬疑/.github/skills/都市悬疑-输出WebNovel版/references/分节级补救映射与详细规则回填.md` | 题材补丁 | 是 | 已回填 |
| 两题材 | 1.3+ 跨文化补强 | 平台共性 | 上下文自然解释而非 glossary | references | 通用WebNovel详细回填 refs | 平台执行细则 | 是 | 已回填 |
| 两题材 | 2-4 | 路径/结构/硬约束 | 输出目录、英文标题、Len≥6500、零中文 | references | 通用WebNovel详细回填 refs | 薄 Prompt 兼容约束 | 是 | 已回填 |
| 两题材 | 5 | 执行前置 | plain English、文化信息嵌入剧情、ending hook | references | 通用WebNovel详细回填 refs | SOP | 是 | 已回填 |
| 异能志怪 | 6 | 题材执行 | trigger/cost/consequence 更清楚 | 题材 Skill | 异能志怪 WebNovel 详细回填 refs | 题材补丁 | 是 | 已回填 |
| 都市悬疑 | 6 | 题材执行 | clue chain/procedure/stakes 清楚可读 | 题材 Skill | 都市悬疑 WebNovel 详细回填 refs | 题材补丁 | 是 | 已回填 |
| 两题材 | 7-8 | 输出/检查 | readability、zero CJK、hook/clue clarity | references | 通用WebNovel详细回填 refs | SOP 终检 | 是 | 已回填 |
