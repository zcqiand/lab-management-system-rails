# 实验室管理系统 Rails 后端

实验室管理系统 Rails 后端（`lab-management-system-rails`）——一句话系统定位（待补）。

本仓为《（书稿信息待补）》案例（待补）的可运行配套工程，是书稿代码块的 **source of truth**。

## 快速开始

```bash
# 前置：ruby + bundler
bundle install                       # 安装依赖（Gemfile.lock 钉版）
bundle exec rubocop --only Layout    # L1 格式
bundle exec rubocop                  # L2 静态（另有 brakeman 安全门）
bundle exec rake test                # L4 测试
bundle exec rails server             # 本地起服务（.env SERVER_PORT=5206）
```

## 功能特性

按特性分点描述核心功能（见 `docs/functions/function-tree.md`）。

## 技术栈

| 技术 | 版本 |
| :--- | :--- |
| Ruby / Rails | 版本全集见 version-lock.json（pg / puma / jwt-gem…） |

> 依赖版本与 `version-lock.json` 的 `version_lock` 一致，不引入 lock 外的库。

## 配套书籍及章节映射

| 章 | 主题 | 对应源文件 |
| :--- | :--- | :--- |
| （待补） | | |

### 书一《Ruby从入门到项目实践》（第二部分）

- 书稿定位：xr-know-012，第 21、22、23、24、25、26、27、28、29、30、31、32 章正文代码块挂本仓 `source=` 锚点
- 配套版本：`v0.1.5-20261004`（registry 冻结 tag，代码以此为准）

| 章 | 章题 | 对应源文件 |
| :--- | :--- | :--- |
| 21 | 项目一启动：实验室管理系统导览与 Rails 入门坡道 | `app/controllers/catalog_controller.rb` |
| 22 | 第一个 CRUD：资源路由与型号字典 | `app/controllers/catalog_controller.rb` |
| 23 | 模型校验与统一错误响应：规格字典 | `app/controllers/catalog_controller.rb` |
| 24 | 关联设计与 link/unlink 模式：专项、项目与标准 | `app/controllers/inspection_dictionary_controller.rb` + `app/services/inspection_dictionary/inspection_junction_service.rb` |
| 25 | 多对多与界面配置：参数、标准关联与参数界面 | `app/controllers/inspection_dictionary_controller.rb` + `app/controllers/param_interfaces_controller.rb` + `app/services/inspection_dictionary/inspection_junction_service.rb` + `app/services/inspection_dictionary/param_interface_junctions.rb` |
| 26 | 从字典到业务单据：合同管理 | `app/controllers/contracts_controller.rb` |
| 27 | 接样单：单据 CRUD、流程历史与详情聚合 | `app/controllers/receipts_controller.rb` + `app/controllers/samples_controller.rb` |
| 28 | 样品与检测记录：嵌套业务数据 | `app/controllers/samples_controller.rb` + `app/controllers/test_records_controller.rb` |
| 29 | 流转与状态机：提交、分配与数据录入 | `app/controllers/receipts_controller.rb` + `app/services/receipts/report_flow_service.rb` |
| 30 | 报告四阶段：审核、批准、发放、归档 | `app/controllers/receipts_controller.rb` + `app/services/receipts/report_flow_service.rb` |
| 31 | 报表与聚合查询：统计仪表盘 | `app/controllers/summary_controller.rb` |
| 32 | 登录、会话与租户初识：项目一收官 | `app/controllers/auth_controller.rb` |
## 快速链接

- [CLAUDE.md](CLAUDE.md) — 开发约定与编码规范
- [系统架构.md](docs/ARCHITECTURE.md) — 结构 / 边界 / 数据流 / 决策
- [功能规格.md](docs/functions/function-tree.md) — 功能名称、描述与验收标准
- [未来开发计划](PLAN.md) — 待办与迭代方向
- [更新日志](CHANGELOG.md) — 版本变更记录
