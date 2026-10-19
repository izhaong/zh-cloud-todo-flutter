# 168 台账（FL #344 第二步：功能栏顺序编辑器）

## 判据源

《01-添加任务》`:24`「添加任务时底部功能栏的顺序支持自定义，点击「...」-「设置」，快速设置你的常用功能」。

## 改动

- [x] 底栏加「…」编辑入口（`todo-quick-add-bar-edit-order`）；
- [x] 顺序编辑器 sheet：四行（拖把手图标 + 上移/下移 IconButton）+ 恢复默认/取消/保存；
- [x] 保存走 `QuickAddActionBarSetting.write`（恰等校验照旧把关）+ `setState` 重渲染；
- [x] **上移/下移而非拖拽**：四个固定项的排序用箭头操作可见、可撤销，不引拖拽依赖。

## 判据与探针

- [x] 2 条（「…」开编辑器 → 上移保存 ⇒ 底栏真的重排；恢复默认 ⇒ 回默认序且落库）；
- [x] **探针**（保存后不 setState）⇒ 红；
- [x] 全量 `+2152 ~26` 0 失败；analyze 0；format rc=0。

## 过程教训（本刀再犯 + 新坑）

1. **`pumpAndSettle` 在本文件再次 10 分钟超时** —— specs/164 的教训白纸黑字写在
   同文件注释里，还是先写了个 `pumpAndSettle(seconds: 1)`。**同坑两次 = 教训要变成
   肌肉记忆：quick-add 相关测试一律固定步 pump**；
2. **widget 测试里没 mock SharedPreferences 的真平台通道会让 fake-async 永不返回**
   （挂死而非报错）—— 编辑器判据开头补 `setMockInitialValues({})`（settings 判据同款）；
3. **判据与操作要逐字对齐**：点一次「上移」= 上移一位，断言却写成"tag 排到最前"
   —— 探针（E saved=date,tag,priority,list）先证写侧，再回头修断言语义。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `quick_add_action_bar_test` | 7 条全绿 |
| 反向探针 | 红 |
| 全量（exclude golden/performance） | `+2152 ~26`，**0 失败** |
