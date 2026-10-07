# REQ-2026-022 M05.F01 仪表盘统计扩展 I03/I04——集成测试锚定 + 树推进

| 项 | 值 |
|---|---|
| 提出人 | Claude（机器侧推进，人已下 standing order） |
| 提出日期 | 2026-10-07 |
| 优先级 | P1 |
| 状态 | 开发中 |
| 关联 ADR | — |

## 1. 需求描述

用户原话（standing order）：「还有很多规划状态没有上线，请继续，加快进程。」

理解：lab 家族 M05.F01.I03（核心指标卡）/I04（任务状态漏斗）在 nextjs/aspnetcore/fastapi 已上线，
react/vue/springboot 已随各自 REQ 推进开发中；rails 服务端扩展段
（todayTestCount/qualifiedRateByMaterial/reportOutputByStatus/funnelByStage）已在库
（2026-09-29 09921f5，javadoc 自证镜像 lab-springboot 同款语义）。本 REQ 不改生产代码，
只做两件事：

1. 集成测试补 `fn` 锚（rails 仓 FN_REGISTRY 机制首次启用）——trace.json 挂上
   M05.F01.I03/I04，对齐 fastapi/springboot 同名测试锚定形态；
2. 功能树 I03/I04 规划→开发中（mirror 正门 --apply，镜像 aspnetcore/fastapi 已上线行
   与 springboot REQ-2026-021 同款推进）。

### 澄清记录

| 疑问 | 澄清结论 | 澄清人 | 日期 |
|---|---|---|---|
| 为什么不直接翻已上线？ | 家族纪律：前端消费 + 人工验收通过后才 GA 翻转；本仓服务端在库但未过人工验收批 | Claude | 2026-10-07 |
| rails 全仓 0 个 fn 锚是否异常？ | 机制（test/fn.rb + TraceReporter）在库但从未使用；本 REQ 首次启用，属补账非破坏 | Claude | 2026-10-07 |

## 2. 验收标准

| 编号 | 场景（给定） | 操作（当） | 预期（则） |
|---|---|---|---|
| AC-1 | 服务端扩展段已在库 | `bundle exec rake test` | 全绿；trace.json tests ≥180、inert 不增、M05.F01.I03 ≥1 且 M05.F01.I04 ≥1 |
| AC-2 | 树已翻开发中 | 三账对齐审计（function-tree / design map / requirements 台账） | 三处状态一致，无悬空引用 |
| AC-3 | 全部改动就位 | `python scripts/gate.py -p lab-management-system-rails`（suite 根） | EXIT=0 |

## 3. 任务拆解

| 任务 ID | 任务描述 | 类型 | 负责人 | 预估 | 状态 |
|---|---|---|---|---|---|
| T-1 | REQ + 树 mirror --apply（I03/I04 规划→开发中）+ design map 2 行 + 台账行 | 账面 | Claude | 0.5h | 完成 |
| T-2 | summary_api_test.rb 补 I03（今日试验/产出量/材料合格率走码表）+ I04（六段漏斗）两个集成测试，体内 `fn` 锚 | 测试 | Claude | 1h | 完成 |
| T-3 | rubocop L1/L2 + brakeman + rake test + trace 校验 + suite gate 全绿，提交推送 | 门禁 | Claude | 0.5h | 完成 |

## 4. 功能影响（需求与功能对齐的唯一位置）

| 功能 ID | 功能名称 | 影响类型 | 说明 | 关联任务 |
|---|---|---|---|---|
| M05.F01.I03 | 核心指标卡 | 变更 | 状态 规划→开发中；补集成测试 fn 锚（服务端已在库） | T-1/T-2 |
| M05.F01.I04 | 任务状态漏斗 | 变更 | 状态 规划→开发中；补集成测试 fn 锚（服务端已在库） | T-1/T-2 |

## 5. 流程影响

无（查询面扩展，不改流程步骤）。

## 6. 风险与回滚

| 风险 | 影响面 | 缓解 | 回滚方式 |
|---|---|---|---|
| FN_REGISTRY 首次启用，键匹配（base_label vs result.name）不符则锚静默落空 | trace.json 空 fns | trace 校验步显式断言 I03/I04 ≥1，落空即红 | 还原测试文件 |
| 集成测试共享 setup 计数漂移 | 新测试假红 | 每个 test 事务回滚隔离，setup 四行即全量事实；计数按 setup 精确断言 | 还原测试文件 |
