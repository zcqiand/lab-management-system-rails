# ARCHITECTURE — lab-management-system-rails

> lab 家族 Rails 8.1 API 后端（:5206，X06 槽位）。saas-identity-platform-rails 的姊妹仓：
> 同一适配器基建（Minitest trace reporter + gen-manifest route-parity），契约面 = lab 域
> （M00-M06：合同/接样/样品/检测记录/检测目录/技术要求/计算方法/报告名/参数接口 + SSO）。
> 行为真源 = lab-management-system-springboot（参照实现）；契约断言真源 =
> lab-management-system-contract-test（live 对拍三后端）。

## 家族定位

- consumes `lab-management-system-shared` TypeSpec SSOT（openapi.yaml 120 op →
  `lib/generated/api_manifest.json` 生成物 committed；`scripts/gen-shared.sh` 刷新）
- DB-First（ADR-0025/0033）：schema 真源 = shared `src/db/schema.ts`；本仓无 db/migrate；
  模型显式 `self.table_name`/`self.primary_key` 对齐真库
- 种子零：lab_dev 数据归 shared seed 链独占；lab_test 由测试自造数据（事务回滚）

## 移植约定（所有 controller/service 的硬规约）

1. **鉴权**：`include JwtGuard`（全业务端点 Bearer typ=access）。匿名放行面只有
   `POST /api/auth/login|native-login|refresh`、`GET|POST /api/auth/sso/**`、
   `GET /health`、`GET /api/_frontend-bind/snapshot`（lab-springboot SecurityConfig 镜像）。
2. **租户解析**：`current_tenant_id`（claim 缺省回退 `LAB_SAAS_DEFAULT_TENANT_ID`）。
   tenant-scoped 域（contracts/receipts/samples/test-records/summary/catalog 4 字典/
   technical-requirements）一律按它过滤；全局字典域不做租户过滤。
3. **时间戳**：TEXT 列，应用层维护 —— `ApplicationRecord.now_iso`（ISO-8601 UTC 带时区，
   镜像 springboot nowIso()）；`record_timestamps=false` 已全局关闭 Rails touch。
4. **id 前缀**：Contract `C-<uuid>` / SampleReceipt `R-<uuid>` / Sample `S-<uuid>` /
   TestRecord `TR-<uuid>`（SecureRandom.uuid）。
5. **响应形状**：camelCase JSON（`render_camel`，深变换 snake_case→camelCase）；
   列表端点用家族分页信封 `{items,page,pageSize,total}`（page=0/pageSize=20 缺省，
   `render_paginated`）—— 分页参数以各 springboot service 实测为准（字典域多为全量
   List 非 envelope，照抄参照实现）。
6. **错误契约**：ApplicationController rescue_from 映射（NSEE→404 NOT_FOUND /
   IAE→400 BAD_REQUEST / NotNullViolation+FK→400 / ParameterMissing+ParseError→400）。
   语义拿不准时看 springboot service 抛什么（IAE vs NoSuchElementException）。
7. **薄控制器**：controller 只做参数提取 + service 调用 + render；业务在
   `app/services/<domain>/`。
8. **测试**：`test/integration/*_test.rb`（ActionDispatch::IntegrationTest + 事务回滚），
   数据用 ActiveRecord 显式造；token 用 `LabAuth::TokenService.new.issue_access` 直签；
   对照 lab-ct 同名断言写（tests/*.test.ts 是行为真源）。fn("Mxx.Fxx.Ixx") 挂树 ID。
9. **禁改** `lib/generated/**`（生成物）；禁 db/migrate；禁 rescue 吞异常。

## 本仓与 saas-rails 的有意差异

- JWT 无 `aud` claim（lab 契约 token 不带 audience）；`typ` claim 强校验
- 路径前缀 `/api`（无 v1 段）
- env 键 = LAB_*（LAB_CORS_ALLOWED_ORIGINS / LAB_SAAS_* / LAB_AUTH_DEV_PASSWORD）+ PG_* 五件套
- SSO 是**客户端**侧：lab 以 OAuth client 身份对接 saas IdP（SaasAuthClient 镜像），
  自签 lab token 内嵌 saas refresh token（`saas_refresh_token` claim）
- lab 库无用户表：登录走 saas（SSO）或 demo 目录（LAB_AUTH_DEV_PASSWORD），
  菜单/权限经 saas /me 快照（MembershipSnapshotCache/MenuSnapshotCache 镜像）

## 门禁

`python scripts/gate.py -p lab-management-system-rails`（suite 根）。
L1/L2=rubocop，L4=rake test（lab_test 真库链，fail-not-skip）。
