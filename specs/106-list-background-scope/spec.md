# 规格：清单背景的两面偏差收口（FL #572，矩阵 #19）

## 判据源（嘀嗒原文）

镜像 `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/02-用清单管理任务.md`（docs 仓）：

- `:100` 配图是整个详情屏（含标题区）都被背景盖住
- `:111`「**图片背景**：图片背景让你的清单更加个性化。」配的是相册/图库选择器

specs/105 落地后矩阵 #19 没翻「有」，原因就是这两面（交叉验证同判：差的是用户拿到的结果，不是措辞）。本规格把这面补齐。

## 需求与裁定

1. **作用域**：背景装饰从"只包任务列表体"改为包住整个详情层（`bareWorkspace` 那一整根 Column：标题区 + 快捷添加 + 分组条 + 列表体），装饰层带专属 key `todo-list-background-surface`。theme（或无效取值）仍回 null ⇒ 一层都不套，默认像素不变。
2. **图片档**：URL 输入框下面加「从相册选择」（key `todo-list-background-pick-image`）——选图（`FilePicker.pickFiles(type: FileType.image)`，本仓倒数纪念日已是同一配方）→ 走 `DioAttachmentUploadApi.uploadFile` 拿 URL → 填回同一格 → 保存仍走 `setBackground`，不落第二条路径。
3. **上传通道可注入**：`pickImage` / `uploadImage` 都是弹层构造参数（不传走真实实现），这样测试不必碰系统选择器与网络。
4. **失败口径**：选图失败与上传失败都就地显示在 `todo-list-background-error`（带 `describeError`），上传中按钮禁用并显示「上传中…」；失败不落任何写入，背景保持原值。

## 诚实登记

- 上传上去的仍是文件服务返回的 URL（`background_value` 存 URL），本端不做嘀嗒那种"图库预置图"分类；离线时图片背景仍会渲染失败，这一点与 specs/105 的登记一致，本单没改变。
- Web 端的 `FileType.image` 走浏览器文件选择框，与移动端的相册不完全同名同形；本轮只在移动端/桌面端语义下描述"相册"。

## 测试与探针

- `test/features/list/list_background_scope_picker_test.dart` 3 例：
  ①控制组先量"默认无装饰层"，再设成颜色背景，断言装饰层存在、包住 `TaskWorkspaceHeader` 与那枚「...」菜单、颜色解析正确；
  ②图片档注入选图/上传 ⇒ 选中的本地路径被送去上传、返回 URL 填回同一格、保存后 `background_type='image'` 与 `background_value=URL` 落库；
  ③上传抛错 ⇒ 错误就地可见、弹层不关、库里背景保持原值。
- 变异探针（commit 后跑，各自红、还原 `cmp -s`）：⑥装饰层退回只包列表体 → 用例 ① 红；⑦选图后不把 URL 填回 → 用例 ② 红；⑧上传失败不捕获（去掉 try/catch 的错误分支）→ 用例 ③ 红。
