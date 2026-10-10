# frozen_string_literal: true

module Auth
  # 登录路径 saas IdP 不可达/5xx → 502 SAAS_UNAVAILABLE（REQ-2026-023：五仓统一码）。
  # 独立文件：ApplicationController 的 rescue_from 在控制器加载期解析本常量，
  # 定义放在 auth_service.rb 内会因 zeitwerk 文件约定加载顺序炸 NameError
  # （与 MenusUnavailable 同款，见该文件注释）。
  # 与 sso 路径的 SaasAuthClient::UpstreamUnavailable（502 SAAS_UPSTREAM_ERROR）分流：
  # 原生登录错误码族与 nextjs/springboot/aspnetcore/fastapi 对齐，不透传 saas 内部详情。
  class SaasIdpUnavailable < StandardError; end
end
