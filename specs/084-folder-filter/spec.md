# 规格：高级筛选补「文件夹」这条筛选条件（矩阵 #22 面 ⑤ 的文件夹半边）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#333（第 251 轮按实测改判，只保留「文件夹」一维；
  「标签」半边已由 FL !418 闭合，判据与改判记录见该 Issue 的留言）
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md`
  - `:50`「按照清单名称、标签、日期等属性进行多维度筛选，还可以按照关键词做内容筛选。」
  - 嘀嗒把文件夹定义为**清单的容器**（《03-如何创建文件夹》）⇒ 本端的「任务属于哪个文件夹」
    必须由任务所在清单的归属推导，不给任务另挂 folder 字段。

## 缺口（改动前，基准 `origin/develop@2ecc0f1055af`）

`TaskFilter.folderId` 是**声明了但两端都没接线**的字段，不是「用户勾了不生效」：

- `git grep -n "folderId:" origin/develop -- lib/features` ⇒ 0 命中
  （正对照：同一命令把串换成 `tagIds:` 得命中 ⇒ 标签有条件构造点，文件夹一个都没有）。
- `git grep -n "filter.folderId" origin/develop -- lib` ⇒ 0 命中 ⇒ 求值侧也没读它。
- `lib/features/filter/filter_bar.dart` 的 `TaskFilter` 字段与 `isEmpty` 里都列着 `folderId`，
  所以它既不会被 UI 赋值，也不影响 `isEmpty` 判定 ⇒ 补一条求值分支单独不构成能力。

## 契约

1. **条件值是本地 folder 主键（String），不是服务端 id（int）**。理由：`TodoFolders.serverId` 可空
   （`lib/core/db/app_database.dart` 的 `TodoFolders` 表），离线新建的文件夹还没有服务端 id，用 int
   这类文件夹根本筛不了；同类的 `TaskFilter.listId` 本来就是本地主键，口径一致。
   改动前 `TaskFilter.folderId` 声明为 `int?` 且 0 个消费点 ⇒ 类型可以直接改，不背历史包袱。
2. **单选 + 再点取消**。文件夹不是多选维度（文档里「按文件夹看」是切一个容器），所以条件是
   `String?`，`_Choice` 再点一次即清空 —— 清空要走 `copyWith(clearFolderId: true)`，
   因为 `folderId ?? this.folderId` 里 null 等于「保留旧值」，不加这条通道就清不掉。
3. **归属索引没就位时不放行全量**。与标签同一口径：`listFolderIds == null` 表示清单流还没发值，
   列表渲染处宁可转圈，预览处宁可给空图报 0 项，也不画一份「文件夹没参与筛选」的结果。
4. **预览与列表同源**：预览用的还是同一个 `applyTaskFilter` 与同一份归属索引，
   「命中 N 项」不会和套出来看到的数不一样。
5. **已保存过滤器的文件夹持久化不在本轮**：`saved_filter_mapping.dart` 把「文件夹」列在 `skipped`
   里，现有行为是「拒绝保存并在对话框点名」，不静默存半个。要闭合需先扩 `zh-cloud-service` 的
   `todo_filter.conditions`（现只有 `listIds/tagIds/dateRange/priorities/statuses/keyword`），
   那一面按「先契约后客户端」另排。
6. **零文件夹与读不出都要可见说明**（四件套③），不能静默退化成一个什么都不列的空小节。

## 验收

- 单元：文件夹条件参与求值（命中/未归类不命中/离线文件夹也能筛/无条件时索引不改变结果）
  —— `test/features/filter/folder_filter_condition_test.dart`。
- 界面：面板里有「文件夹」小节且选项来自文件夹流、选→预览命中数变、再点→回原状、
  应用后筛选条上显示「文件夹」且列表真的只剩该文件夹的任务、零文件夹给提示
  —— `test/features/filter/advanced_filter_folder_condition_test.dart`。
- 门禁：`flutter analyze` rc=0；全量 `flutter test`（含 golden 9 张，未重录）通过。
