# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Auth
  # saas IdP 真对接（lab-springboot SaasAuthClient 镜像，RestClient → Net::HTTP）。
  # - service_login：服务账号密码登 saas /api/v1/auth/login（密码登录用户拉菜单快照用）
  # - token：OAuth §4.1.3/§6 code 换 token 或 refresh_token 续（/api/v1/oauth/token）
  # 错误映射：401→UnauthorizedClient / 4xx→InvalidGrant / 5xx+网络→UpstreamUnavailable。
  class SaasAuthClient
    class InvalidGrant < StandardError; end
    class UnauthorizedClient < StandardError; end
    class UpstreamUnavailable < StandardError; end

    TokenResponse = Struct.new(:access_token, :refresh_token, :token_type, :expires_in, :scope,
                               keyword_init: true)

    def initialize(
      saas_base: ENV.fetch('LAB_SAAS_BASE_URL'),
      client_id: ENV.fetch('LAB_SAAS_CLIENT_ID'),
      client_secret: ENV.fetch('LAB_SAAS_CLIENT_SECRET'),
      default_tenant_id: ENV.fetch('LAB_SAAS_DEFAULT_TENANT_ID'),
      service_client_id: ENV.fetch('LAB_SAAS_SERVICE_CLIENT_ID')
    )
      @saas_base = saas_base.chomp('/')
      @client_id = client_id
      @client_secret = client_secret
      @default_tenant_id = default_tenant_id
      @service_client_id = service_client_id
    end

    # body 对齐 saas LoginRequest 契约 {username, password, clientId}（2026-09-19 5.33 同款）
    def service_login(username, password)
      post_json('/api/v1/auth/login', username: username, password: password,
                                      clientId: @service_client_id)
    end

    def token(grant_type, code: nil, refresh_token: nil, redirect_uri: nil)
      body = { grantType: grant_type, clientId: @client_id, clientSecret: @client_secret,
               tenantId: @default_tenant_id }
      body[:code] = code if code
      body[:refreshToken] = refresh_token if refresh_token
      body[:redirectUri] = redirect_uri if redirect_uri
      post_json('/api/v1/oauth/token', **body)
    end

    private

    def post_json(path, body)
      uri = URI("#{@saas_base}#{path}")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = JSON.generate(body)
        http.request(req)
      end
      case res.code.to_i
      when 200..299 then parse_token(res.body)
      when 401 then raise UnauthorizedClient, 'saas 401 unauthorized_client'
      when 400..499 then raise InvalidGrant, "saas #{res.code} #{truncate(res.body)}"
      else raise UpstreamUnavailable, "saas upstream 5xx: #{res.code}"
      end
    rescue SocketError, Errno::ECONNREFUSED, Timeout::Error => e # Timeout::Error 含 Net::OpenTimeout
      raise UpstreamUnavailable, "saas connect failed: #{e.message}"
    end

    def parse_token(raw)
      h = JSON.parse(raw)
      TokenResponse.new(
        access_token: h['accessToken'], refresh_token: h['refreshToken'],
        token_type: h['tokenType'], expires_in: h['expiresIn'], scope: h['scope']
      )
    end

    def truncate(s, max = 200)
      return '' if s.nil?

      s.length <= max ? s : "#{s[0, max]}..."
    end
  end
end
