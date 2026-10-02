# 规格：详情标签选择器的空态文案改指真的入口（FL Issue #332，第 168 轮）

分支 `fix/332-tag-empty-entry`，基线 `zh-cloud-todo-flutter origin/develop`（取数基准现读）。
台账见同目录 `tasks.md`。

## 一、判据源与措辞

嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:16「点击侧边栏右下角「设置」进入清单管理页，
点击「标签」，选择「显示」即可。」讲的是侧栏「标签」这一档。本端没有嘀嗒那张「清单管理页」——
可达性由下面第二节的扫库判据现读——标签管理的真入口是侧栏那行 label「标签」。
本单不改交互，只把空态文案指到**真的点得到的那一处**，措辞沿用源页的「标签」二字，不自创同义词。

## 二、缺陷判据（改前，基准 `origin/develop`）

| 面 | 复算命令 | 读数 |
| --- | --- | --- |
| 旧文案把用户指向清单页 | `git grep -n "暂无标签，请先在清单页右上角创建" origin/develop -- lib` | 命中 `lib/features/task/task_detail_pane.dart:3373`（上一版这里写 3398 是抄了 !427 分支那个工作树的行号：那笔实现给同一文件加了 25 行 ⇒ 只对本分支成立，对 `origin/develop` 不成立） |
| 清单页其实没有入口 | 新增用例逐行扫 `lib/` 里出现 `ListPage(` 的行，按「前一个字符不是字母」排除 `TasksByListPage(` | 只剩 `lib/features/list/list_page.dart:18` 自身的构造声明 |
| 真入口存在 | `git grep -n "todo-sidebar-row-tags" origin/develop -- lib` | 命中 `lib/features/shell/sidebar.dart:243`，其 `onTap` 调 `lib/features/home/home_shell.dart:496` 的 `_openTags` 推 `TagPage` |

## 三、方案（一行文案 + 一条护栏）

`lib/features/task/task_detail_pane.dart` 的空态文本改为「暂无标签，可先在侧栏「标签」里创建」；
同一次提交带 `test/features/task/tag_empty_state_entry_test.dart`，其中第二条用例把「清单页不可达」
钉成回归护栏：将来给 `ListPage` 真加了入口，那条用例会红，提示这句话的归属要重判，
而不是让文案悄悄过时。
