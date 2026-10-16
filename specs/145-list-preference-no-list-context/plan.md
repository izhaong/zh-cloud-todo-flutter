# 145 计划

1. 读原单后半，确认两个仓储都把 null 落成 'inbox'。
2. 从 `home_shell._effectiveListId` 取证：生产里收集箱传字面量 `'inbox'`，从不传 null。
3. 写一次性探针证「改智能清单会顶掉收集箱」（先红）。
4. 两个仓储各加 `_noListSourceKey = 'no-list'`。
5. **关键**：把 `'no-list'` 加进 `ListViewPreferenceScope.deviceNeutralKeys`，
   否则同步层会把它当清单 UUID 归一，跨端又各写各的。
6. 排查并订正 3 条「把 null 当收集箱」的存量用例。
7. 门禁：探针转绿、反向探针红、analyze 0、全量 0 失败。
