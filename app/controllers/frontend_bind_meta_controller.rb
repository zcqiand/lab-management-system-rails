# frozen_string_literal: true

# GET /api/_frontend-bind/snapshot —— 生成器 DTO（registry/authContext/tokenKeys）存在但
# lab-springboot 无 @RestController 实现；ct 也不测本端点。rails 1:1 镜像：action 存在
# （route-parity 要求）。挂 JwtGuard：springboot 该路径不在 permitAll 名单，Security
# 过滤链先于 404 handler → 匿名 401（2026-09-29 review Important 补 include）。
class FrontendBindMetaController < ApplicationController
  include JwtGuard

  def get_frontend_bind_snapshot
    render_error(:not_found, 'NOT_FOUND', 'resource not found')
  end
end
