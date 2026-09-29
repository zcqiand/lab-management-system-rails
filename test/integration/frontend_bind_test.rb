# frozen_string_literal: true

# GET /api/_frontend-bind/snapshot —— 生成器 DTO 契约面（lab-springboot 无
# @RestController 实现；Security 过滤链先于 404 handler，匿名请求 401 而非 404）。
# 2026-09-29 review Important：类注释声称挂 JwtGuard 但未 include，匿名曾 404。
require 'test_helper'

class FrontendBindTest < ActionDispatch::IntegrationTest
  test 'snapshot anonymous request is 401 (Security chain before 404 handler)' do
    get '/api/_frontend-bind/snapshot'
    assert_equal 401, response.status
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(response.body)['code']
  end
end
