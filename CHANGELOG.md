# 更新日志

格式照 `v<MAJOR>.<MINOR>.<PATCH>-<YYYYMMDD>`（tag 即放行：全量回归绿后打 tag）。

历史版本（tag 底账，明细见 git log）：

- `v0.1.9-20261011`（2026-10-11）— chore(retire): LAB_AUTH_DEV_PASSWORD 退役——原生登录代理 saas IdP (REQ-2026-023)
- `v0.1.8-20261007`（2026-10-07）— feat(m05): REQ-2026-022 仪表盘统计扩展——I03/I04 集成测试 fn 锚 + 树推进开发中(mirror --apply)
- `v0.1.7-20261006`（2026-10-06）— chore(env): dev CORS 白名单追加 flutter 5208（REQ-2026-002 联调）
- `v0.1.6-20261004`（2026-10-04）— docs(handoff): 收录 code-suite-handoff v1 写书事实底
- `v0.1.5-20261004`（2026-10-04）— chore(license): 补 MIT LICENSE —— xr-know-012 case-import 前置（LICENSE-only 一笔）
- `v0.1.4-20261003`（2026-10-03）— docs(anchor): xr-know-012 案例注锚——74 fn-ID 落位 12 文件 +81 行纯注释（gate 全绿）
- `v0.1.3-20261002`（2026-10-02）— docs(req): lab-rails REQ-2026-001 T-3 证据增补——改动后实测 gate + curl 四验
- `v0.1.2-20261002`（2026-10-02）— docs(req): REQ-2026-001 根路径跳转 Swagger 对齐文档——功能影响 0（基础设施端点不进树，待评审）
- `v0.1.1-20260929`（2026-09-29）— fix(config): prod 关 force_ssl（TLS 由 nginx 终结）
- `v0.1.0-20260929`（2026-09-29）— fix(ci): bin/* shebang 去 Windows 化（ruby.exe → ruby）+ eager-load 走 bundle exec
