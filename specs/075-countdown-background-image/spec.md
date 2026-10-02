# 倒数纪念日消费背景图（FL Issue #445 消费面）

## 判据源原文

zh-cloud-docs `todo/99_参考资料/dida365-help-center/02-功能指南/06-倒数纪念日/02-打造专属纪念页.md` 的「自定义图片」一节：

- mobile：「选择图片样式后，切换到「图片」选项，即可替换图片或者上传心仪的背景图，让每一个纪念日更加生动有趣。」
- desktop：「在样式编辑窗口，点击「切换图片」，可以上传新的背景图片，让每一个纪念日更加生动有趣。」

术语固定「背景图」，不自创「封面」「主题图」。

## 契约现状（不是前端能自己造的）

zh-cloud-service `origin/develop` 里这一列已通到底：`sql/mysql/modules/todo-baseline-2026-09-18.sql` 有 `background_image` varchar(512)；`TodoCountdownDO` 有 `backgroundImage` 字段；`AppTodoCountdownBaseVO` 与 `AppTodoCountdownRespVO` 都带该字段，`TodoCountdownServiceImpl` 在 create 与 update 两处写入。FL 侧 `CountdownDto` 早已解析该键但界面不消费 ⇒ 本规格只做消费面。

## 功能需求

- FR-1 卡片要按该条记录自己的 `backgroundImage` 画背景；空值时不得冒名画一张。
- FR-2 取图失败必须收敛（不抛穿），且不得吃掉已加载的标题与天数。
- FR-3 背景图要有读屏标签，念得出「<标题> 的背景图」。
- FR-4 窄屏与放大字号下背景图与文字同屏，不得把行撑破。

## 范围外

「切换图片 / 上传背景图」这一面不在本规格：FL 全仓没有网络图渲染先例，上传要走文件通道，得先判 zh-cloud-service 既有 `AppTodoAttachmentController` 的 `/upload`（`@RequestBody`，非 multipart）覆不覆盖倒数纪念日背景图，缺则先修契约。判据与推理见 FL Issue #445 正文。
