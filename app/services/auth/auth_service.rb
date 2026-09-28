# frozen_string_literal: true

module Auth
  # 认证域服务（lab-springboot AuthService 1:1 镜像，ADR-0008）：
  # - JWT：LabAuth::TokenService 出真签名（HS256）
  # - SSO：SaasAuthClient 真调 saas /oauth/token；SaasMeClient 拿 /me 快照
  # - CSRF：state 由前端生成，后端透传（RFC 6749 §10.12），后端不校验
  # - refresh：lab refresh token 内嵌 saas refresh token（rotate-once）
  # 菜单/租户快照：进程内 30min TTL（SnapshotCache），SSO/refresh/密码登录时点填充。
  class AuthService
    # msw 权限集（admin 全量 11 项，handlers-extra.ts:160-175 镜像）
    DEMO_PERMISSIONS = %w[
      contract:read contract:write sample:read sample:write report:read report:write
      report:issue inspection:read inspection:write audit:read *
    ].freeze

    # lab 家族在 saas 注册的 appCode（seeds apps.json）
    LAB_APP_CODE = 'lab-management'

    # DI 端口清单：实例变量名 → 缺省实现（initialize kwargs 全可注入）
    DEFAULT_DEPS = {
      directory: UserDirectory, saas_auth: SaasAuthClient, saas_me: SaasMeClient,
      token_service: LabAuth::TokenService, menu_cache: SnapshotCache,
      membership_cache: SnapshotCache, menu_mapper: SaasMenuMapper
    }.freeze

    # 进程内单例（目录与快照缓存跨请求存活；test 用 .reset! 隔离）
    def self.instance
      @instance ||= new
    end

    def self.reset!
      @instance = nil
    end

    # kwargs 全缺省 = DI 缝（测试注入 stub 用）；显式端口清单在 DEFAULT_DEPS
    def initialize(**deps)
      DEFAULT_DEPS.each do |name, klass|
        instance_variable_set("@#{name}", deps.fetch(name) { klass.new })
      end
    end

    attr_reader :directory, :saas_auth, :saas_me

    # === 密码登录（M01.F05.I01；native-login 同口径） ===

    def login(body)
      username = body[:username].to_s.strip
      password = body[:password].to_s
      raise ArgumentError, 'username and password are required' if username.empty? || password.empty?
      unless @directory.check_password?(username, password)
        raise ApplicationController::InvalidCredentials, 'Invalid username or password'
      end

      user = @directory.find_by_username(username)
      raise ApplicationController::InvalidCredentials, 'unknown user' unless user

      # 密码登录的 dev 用户无 saas 身份 → 服务账号拉菜单快照；失败不阻塞登录
      cache_menus_with_service_account(user.id)
      session(user, nil, nil)
    end

    # === 刷新 token（M01.F05.I04） ===

    def refresh(body)
      token = body[:refreshToken].to_s
      raise ApplicationController::InvalidCredentials, 'missing refresh_token' if token.empty?

      claims = @token_service.verify!(token, typ: LabAuth::TokenService::TYP_REFRESH)
      saas_refresh = claims['saas_refresh_token'].to_s
      if saas_refresh.empty?
        raise ApplicationController::InvalidCredentials,
              'invalid refresh_token: missing saas_refresh_token claim'
      end

      t = @saas_auth.token('refresh_token', refresh_token: saas_refresh)
      hydrate_and_session(claims['tenant_id'], t)
    rescue JWT::DecodeError => e # 基类含 ExpiredSignature 与 typ 校验错
      raise ApplicationController::InvalidCredentials, "invalid refresh_token: #{e.message}"
    rescue SaasAuthClient::InvalidGrant, SaasAuthClient::UnauthorizedClient => e
      raise ApplicationController::InvalidCredentials, "saas refresh failed: #{e.message}"
    end

    # === 登出（无状态 JWT，服务端无 session store） ===

    def logout(_body); end

    # === 当前会话（M00.F01.I01） ===

    def me(claims)
      user = resolve_user(claims)
      saas_refresh = @directory.get_saas_refresh_token(user.id)
      if saas_refresh.present?
        cached = @membership_cache.get(user.id)
        if cached.blank?
          raise ApplicationController::InvalidCredentials,
                "membership snapshot unavailable for user #{user.id} (cache miss); refresh required"
        end
        current = claims['tenant_id'].presence || cached.first[:tenant_id]
        return { user: user_struct(user), tenants: cached, currentTenantId: current }
      end

      current = claims['tenant_id'].presence || @directory.default_tenant.tenant_id
      { user: user_struct(user), tenants: directory_tenants(user), currentTenantId: current }
    end

    # === 选租户换发（M00.F02.I01） ===

    def switch_tenant(claims, body)
      user = resolve_user(claims)
      tenant_id = body[:tenantId].to_s
      target = @directory.find_by_tenant_id(tenant_id)
      raise ActiveRecord::RecordNotFound, 'Tenant not found' unless target

      session(user, target.tenant_id, nil)
    end

    # === 动态菜单 / 权限集（M01.F04.I01/I02） ===

    # miss（快照过期/密码登录未填充/重启）抛 MenusUnavailable → 503；
    # demo 兜底已删（2026-08-27），前端 useBackendMenus 失败回退静态菜单。
    def menus(claims)
      sub = claims && claims['sub']
      snapshot = @menu_cache.get(sub)
      raise MenusUnavailable, "menu snapshot unavailable for user #{sub}; re-login to refresh" if snapshot.blank?

      snapshot
    end

    def permissions
      { permissions: DEMO_PERMISSIONS }
    end

    # === SSO 跳转（M01.F05.I02） ===

    # 302 跳板语义（2026-08-29 收敛）：直接回 saas 登录页 URL（带 redirect_uri+state+client_id），
    # 调用方 redirect_uri 缺失 fail-fast（ADR-0019，2026-09-23 跨前端事故同款）。
    def sso_authorize(business_redirect, frontend_state)
      raise ArgumentError, 'missing redirect_uri' if business_redirect.blank?

      state = frontend_state.to_s
      authorize_url = "#{ENV.fetch('LAB_SSO_LOGIN_URL')}/login" \
                      "?redirect_uri=#{CGI.escape(business_redirect)}" \
                      "&state=#{CGI.escape(state)}" \
                      "&client_id=#{CGI.escape(ENV.fetch('LAB_SAAS_CLIENT_ID'))}"
      { 'authorizeUrl' => authorize_url, 'state' => state }
    end

    # === SSO 回调（M01.F05.I03） ===

    def sso_callback(body)
      raise ArgumentError, 'missing body' if body.blank?

      t = @saas_auth.token('authorization_code', code: body[:code].to_s,
                                                 redirect_uri: body[:redirectUri].presence)
      hydrate_and_session(nil, t, callback: true)
    rescue SaasAuthClient::InvalidGrant => e
      raise e # 400 INVALID_GRANT（code 重放/过期，对齐 lab-msw 契约）
    rescue SaasAuthClient::UnauthorizedClient => e
      raise ApplicationController::InvalidCredentials, e.message
    end

    private

    # saas token 到手后的公共水合：whoami → upsert 目录 → 菜单快照 → refresh token
    # 存回（rotate-once）→ 平台租户名富化 → memberships 快照 → 签发会话。
    def hydrate_and_session(tenant_id, t, callback: false)
      saas_user = @saas_me.whoami(t.access_token)
      lab_user = upsert_lab_user(saas_user)
      cache_menus(lab_user.id, t.access_token)
      @directory.set_saas_refresh_token(lab_user.id, t.refresh_token)
      tenants = snapshot_memberships(lab_user.id, t.access_token)
      session(lab_user,
              callback ? saas_user['currentTenantId'] : tenant_id,
              tenants, t.refresh_token)
    rescue SaasMeClient::UpstreamUnavailable => e
      raise SaasAuthClient::UpstreamUnavailable, e.message
    end

    # saas email 桥接目录 upsert（ADR-0008）：命中即复用，未命中以 viewer 落地
    def upsert_lab_user(saas_user)
      @directory.find_by_email(saas_user['email'].to_s) || @directory.upsert(
        saas_user['id'].to_s, saas_user['email'].to_s, saas_user['displayName'].to_s, 'viewer'
      )
    end

    # memberships 快照 + 平台租户名富化，进缓存（me() 的 SSO 租户体系数据源）
    def snapshot_memberships(user_id, saas_access_token)
      name_by_id = fetch_tenant_names(user_id, saas_access_token)
      tenants = tenants_from(@saas_me.list_my_tenants(saas_access_token), name_by_id)
      @membership_cache.put(user_id, tenants)
      tenants
    end

    def resolve_user(claims)
      sub = claims && claims['sub'].to_s
      raise ApplicationController::InvalidCredentials, 'missing sub claim' if sub.empty?

      @directory.find_by_id(sub) || @directory.find_by_email(sub) ||
        @directory.find_by_username(sub) or
        raise ApplicationController::InvalidCredentials, "unknown user: #{sub}"
    end

    def session(user, tenant_id, tenants, saas_refresh_token = nil)
      access_token = @token_service.issue_access(user.id, tenant_id)
      refresh_token = @token_service.issue_refresh(user.id, saas_refresh_token || 'dev-placeholder')
      use_tenants = tenants || directory_tenants(user)
      { token: access_token, refreshToken: refresh_token, user: user_struct(user),
        tenants: use_tenants }
    end

    def directory_tenants(user)
      @directory.tenants_of(user.username).map { |t| tenant_struct(t) }
    end

    # memberships → MyTenant hash；名字富化 miss 降级 code=name=tenantId（切租户器不空）
    def tenants_from(memberships, name_by_id)
      (memberships || []).map do |m|
        t = name_by_id[m['tenantId']] || {}
        { tenant_id: m['tenantId'],
          code: t['tenantKey'].presence || m['tenantId'],
          name: t['name'].presence || m['tenantId'],
          role_ids: m['roleIds'] || [] }
      end
    end

    # 失败只 warn 返空（best-effort，不阻塞登录；名字降级 tenantId）
    def fetch_tenant_names(user_id, saas_access_token)
      return {} if user_id.nil? || saas_access_token.nil?

      @saas_me.list_platform_tenants(saas_access_token)
              .select { |t| t['id'].present? }
              .index_by { |t| t['id'] }
    rescue StandardError => e
      Rails.logger.warn("tenant name lookup failed for user #{user_id}: #{e.message}")
      {}
    end

    # SSO/refresh 时点唯一持有 saas accessToken 的窗口，顺手拉菜单快照；失败不阻塞
    def cache_menus(user_id, saas_access_token)
      return if user_id.nil? || saas_access_token.nil?

      snapshot = @saas_me.list_my_menus(saas_access_token, LAB_APP_CODE)
      @menu_cache.put(user_id, @menu_mapper.map(snapshot))
    rescue StandardError => e
      Rails.logger.warn("menu snapshot fetch failed for user #{user_id}: #{e.message}")
    end

    # 密码登录路径：用服务账号登 saas 换 token 再拉菜单；失败只 warn
    def cache_menus_with_service_account(user_id)
      return if user_id.nil?

      t = @saas_auth.service_login(ENV.fetch('LAB_SAAS_SERVICE_USER'),
                                   ENV.fetch('LAB_SAAS_SERVICE_PASSWORD'))
      cache_menus(user_id, t.access_token)
    rescue StandardError => e
      Rails.logger.warn("service-account menu snapshot failed for user #{user_id}: #{e.message}")
    end

    def user_struct(user)
      { id: user.id, username: user.username, displayName: user.display_name,
        roleCode: user.role_code }
    end

    def tenant_struct(t)
      { tenant_id: t.tenant_id, code: t.code, name: t.name, role_ids: t.role_ids }
    end
  end

  # 菜单快照不可用 → 503 MENUS_UNAVAILABLE（GlobalExceptionHandler 镜像）
  class MenusUnavailable < StandardError; end
end
