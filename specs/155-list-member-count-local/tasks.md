# 155 台账

## T1 取证

- [x] `TodoLists` 有 `accessRole` 但**没有**成员数；`accessRole` 判不出"我建的共享清单"。
- [x] 服务端 `list` 载荷已带 `memberCount`（`specs/054` !400）。

## T2 改动

- [x] 列 `memberCount`（默认 1）+ 迁移 `from < 31` + `schemaVersion` 31。
- [x] pull 映射（两种键名 + 保留旧值）。
- [x] `dart run build_runner build` 重生成（drift 生成物里 44 处 `memberCount`）。

## T3 判据与探针

- [x] 两条用例（落库 / 缺键保留），跑绿。
- [x] **反向探针**：摘掉映射 ⇒ `Expected: <3> Actual: <1>`，转红。

## T4 连带的既有测试订正（加列的必然代价）

加一列 + 推一格 schema 会**必然**碰三类既有测试，这次三类都碰到了：

| 类 | 表现 | 订正 |
| --- | --- | --- |
| **构造 `TodoList(...)`** | 编译失败：`Required named parameter 'memberCount' must be provided`（drift 生成的 data class 对**非空列**一律要求构造参数，**即使列有默认值**） | 2 处补 `memberCount: 1` |
| **断言 `PRAGMA user_version`** | 期望 30 / 实得 31 | `app_database_migration_test.dart` 共 **19 处**（6 空格缩进 9 处 + 4 空格缩进 10 处，**正则一次改不干净**，先按缩进改漏了 2 处） |
| **断言 `db.schemaVersion`** | 期望 30 / 实得 31 | 2 处 |

**教训**：加列不是"改两行"。**先把这三类测试找齐再动手**，比跑一遍全量再逐个修快得多。
另外 `expect(x, 30)` 这种断言在同一文件里可能有**多种缩进/写法**，正则要覆盖全。

## 过程教训

1. **加列之后必须重生成**：不跑 `build_runner` 时，`analyze` 报的是
   「`memberCount` 未定义」—— 看起来像代码写错，其实是生成物旧了。
2. **"缺键保留"这个决定要写在代码里**：`?? 1` 是很自然的一行，
   但它会把"共享清单"静默降级成"个人清单"。**看得见的错与看不见的错不是一回事。**

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 该文件 | `+2 All tests passed!` |
| 反向探针 | 转红 |
| `flutter analyze` | 0 issue |
| 全量（exclude golden/performance） | `+2109 ~26`，**0 失败**（较修前 +1 = 本单新增） |
