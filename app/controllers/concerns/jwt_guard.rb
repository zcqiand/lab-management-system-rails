# frozen_string_literal: true

# lab 家族鉴权门（lab-springboot NimbusLabJwtDecoderFactory + SecurityConfig 镜像）：
# 全业务端点 Bearer JWT（typ=access，iss=JWT_ISSUER）；匿名放行面只有
# auth login/native-login/refresh/sso/** + /health + /api/_frontend-bind/snapshot。
# 缺/坏/过期 token -> 401（INVALID_CREDENTIALS）—— 身份字段缺失禁兜底（ADR-0019）。
module JwtGuard
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_jwt!
  end

  private

  def authenticate_jwt!
    header = request.headers['Authorization'].to_s
    token = header.delete_prefix('Bearer ').strip
    raise ApplicationController::InvalidCredentials, 'missing bearer token' if token.empty? || header == token

    @jwt_claims = lab_token_service.verify!(token)
  rescue JWT::ExpiredSignature, JWT::DecodeError, JWT::InvalidPayloadError => e
    raise ApplicationController::InvalidCredentials, e.message
  end

  # 当前会话 claims（sub / tenant_id? / typ）
  def current_claims
    @jwt_claims or raise ApplicationController::InvalidCredentials, 'no session'
  end

  def current_user_id
    current_claims['sub']
  end

  # 家族约定：claim tenant_id 缺省回退 directory 默认租户 TENANTS[0]（TENANT-001）
  # （lab-springboot InspectionCatalogController.currentTenantIdOrDefaultStatic 镜像）。
  # 2026-09-29 live 实锤：误兜 LAB_SAAS_DEFAULT_TENANT_ID（saas 服务账号域 GUID），
  # create 回显 tenantId 与 nextjs/springboot 分叉 —— 业务租户域与 saas 域分离。
  def current_tenant_id
    claim = current_claims['tenant_id']
    return claim unless claim.blank?

    Auth::UserDirectory.new.default_tenant.tenant_id
  end

  def lab_token_service
    @lab_token_service ||= LabAuth::TokenService.new
  end
end
