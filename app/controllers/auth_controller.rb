# frozen_string_literal: true

# M00.F01/F02 + M01.F04/F05 认证域（薄层）：claims 从 JwtGuard 取，业务在 Auth::AuthService。
# 匿名放行面（lab-springboot SecurityConfig 镜像）：login / native-login / refresh / sso/**；
# logout 与 me/menus/permissions/switch-tenant 均需 Bearer。
class AuthController < ApplicationController
  include JwtGuard

  skip_before_action :authenticate_jwt!, only: %i[login native_login refresh sso_authorize sso_callback]

  def get_current_user
    render_camel(service.me(current_claims))
  end

  def get_menus
    render json: ApiSupport::JsonCamelizeKey.call(service.menus(current_claims))
  end

  def get_permissions
    render_camel(service.permissions)
  end

  def login
    render_camel(service.login(body))
  end

  # M01.F05.I06 原生登录：非浏览器密码通道，校验与签发口径与 login 同源
  def native_login
    render_camel(service.login(body))
  end

  def logout
    service.logout(body)
    head :no_content
  end

  def refresh
    render_camel(service.refresh(body))
  end

  # M01.F05.I02 — 返回 {authorizeUrl, state} 跳板（2026-08-29 收敛，服务端不预拿 code）
  def sso_authorize
    render_camel(service.sso_authorize(params[:redirectUri], params[:state]))
  end

  # M01.F05.I03 — code 换 token；state 校验已在前端回跳时完成
  def sso_callback
    render_camel(service.sso_callback(body))
  end

  def switch_tenant
    render_camel(service.switch_tenant(current_claims, body))
  end

  private

  def service
    @service ||= Auth::AuthService.instance
  end

  def body
    @body ||= begin
      request.body.rewind
      JSON.parse(request.body.read).deep_symbolize_keys
    rescue JSON::ParserError
      {}
    end
  end
end
