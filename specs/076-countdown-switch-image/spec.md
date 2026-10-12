# 倒数纪念日「切换图片」上传背景图（FL Issue #445 上传面）

## 判据源原文（照抄术语）

zh-cloud-docs `todo/99_参考资料/dida365-help-center/02-功能指南/06-倒数纪念日/02-打造专属纪念页.md` 的「自定义图片」一节：
mobile「选择图片样式后，切换到「图片」选项，即可替换图片或者上传心仪的背景图」；
desktop「在样式编辑窗口，点击「切换图片」，可以上传新的背景图片」。入口文案取「切换图片」，不自创「封面」「主题图」。

## 契约现状

服务端 app 侧收得到这一键：`AppTodoCountdownCreateReqVO` 与 `AppTodoCountdownUpdateReqVO` 都继承 `AppTodoCountdownBaseVO`，其后者的 `backgroundImage` 由 `TodoCountdownServiceImpl` 在 create 与 update 两处写入；FL 侧上传通道也是现成的（`lib/core/api/attachment_upload_api.dart` 的 `uploadFile` 走 infra 文件服务并返回 URL）。⇒ 本面不需要先改 zh-cloud-service。

## 功能需求

- FR-1 倒数纪念日编辑窗口要有「切换图片」入口，选完图上传后把返回地址设为该条记录自己的背景图。
- FR-2 保存时 create 与 update 的 payload 必须真带 `backgroundImage`，否则界面选了等于没选。
- FR-3 上传失败要给出可见原因，且**已有背景图不被吃掉**；取消选择不报错也不改值。
- FR-4 该入口自带读屏语义（`button` 加 label），窄屏 320 宽与 1.3 倍字号下仍完整可见可点。
