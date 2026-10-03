# 倒数纪念日归档与恢复（矩阵 #50）

## 背景

嘀嗒《02-功能指南/06-倒数纪念日/03-管理倒数纪念日.md》的「归档」一节逐字写着：

- 「进入倒数纪念日页面，点击右上角「...」-「归档」，即可将它收纳到「已归档」列表中，整洁又不丢失重要回忆。」
- 查看：「要查看已归档的倒数日，可以在倒数日页面点击右上角「...」-「已归档」，即可查看所有归档的内容。」
- 恢复：「进入「已归档」页面，找到需要恢复的倒数纪念日，点击右上角「...」-「恢复」，即可取消归档，重新回到主列表。」

对照矩阵 `zh-cloud-docs/todo/01_需求阶段/对照矩阵/dida-parity-matrix.md` 的 #50「管理倒数纪念日」，编辑与删除早已合并（`24005fce`），缺的就是「归档」「已归档」「恢复」这一条回路。

## 契约前提（已存在，本规格不改后端）

服务端 `zh-cloud-service` `origin/develop` 已有：

- `TodoCountdownDO` 的 `archived` 列；`AppTodoCountdownRespVO` 的 `archived` 字段
- `PUT /todo/countdown/{id}/archived`，查询参数名为 `value`
- `GET /todo/countdown/list?archived=`，不传等于 `false`，即主列表

Flutter 侧缺的三件事，全在本仓库内可补齐：`CountdownDto` 没有 `archived` 字段；`CountdownApi.list()` 不传 `archived`；没有调用归档端点的方法；页面上没有归档入口。判据（现跑）：`grep -c archived lib/core/api/efficiency_api.dart` 在 `CountdownDto` 类体内为 0，`grep -c 'countdown/' lib/core/api/efficiency_api.dart` 只覆盖 create、delete、list、update 四条路径。

## 验收标准

- Given 主列表有未归档的倒数纪念日 When 打开该条右上角「...」 Then 菜单里有「归档」一项，读屏能念出「归档」
- Given 用户点「归档」 When 服务端返回成功 Then 该条从主列表消失（列表重取），且发出的是 `PUT /countdown/{id}/archived?value=true`
- Given 用户在倒数日页 When 打开右上角「...」并选「已归档」 Then 进入已归档视图，只列 `archived` 为真的条目
- Given 已归档视图有条目 When 打开该条「...」并选「恢复」 Then 发出 `value=false`，该条不再出现在已归档视图
- Given 归档或恢复请求失败 When 页面收到异常 Then 已加载的列表数据仍显示（不许变空），并在该页可见位置给出失败提示与重试
- Given 视口宽 320 逻辑像素且字号放大到 1.3 倍 When 打开倒数日页与「...」菜单 Then 归档入口与菜单项仍完整可见、可点，不溢出
- Given 主列表响应慢、已归档响应快 When 用户先请求主列表再切到已归档 Then 迟到的主列表响应不得覆盖已归档视图（过期响应不覆盖新响应）

## 范围之外

嘀嗒「分组」一节要求的「显示分组」开关与四类自动分组（**倒数日、纪念日、生日、节日**）不在本规格内：它依赖 `type` 列在 `GET /list` 上的过滤或分组返回，属后端契约面，另单跟踪（zh-cloud-service #304）。
