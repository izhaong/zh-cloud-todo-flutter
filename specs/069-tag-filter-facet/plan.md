# 069 · 计划

1. `TagRepository.watchTagIndex()`（整表 join，一次拿全）→ `taskTagIndexProvider`。
2. `applyTaskFilter` 增可选命名参数 `taskTagIds`，加「且」分支（超集才算命中）；`null` 表示索引未就位 ⇒ 不参与求值，由调用方决定画加载态还是 0 项。
3. 列表渲染与高级筛选预览两处同源传参（`ref.watch` / `ref.read` 同一个 provider）。
4. 撤 `saved_filter_mapping.dart` 里 `tagIds` 非空即 `return null` 的守卫，并把既有 widget 用例的期望改成新事实（保留 `in_progress` 这条真不支持的判据）。
5. 门禁六道 + 反向探针 + 台账 + PR。
