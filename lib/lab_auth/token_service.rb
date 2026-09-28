# frozen_string_literal: true

require 'jwt'

module LabAuth
  # lab 自签 JWT（HS256）—— lab-springboot LabJwtSigner 的 Ruby 镜像。
  # - access:  {sub, tenant_id?, typ=access, iss, iat, exp}（1h；无 aud claim —— lab
  #   契约 token 不带 audience，与 saas 家族 verifier 的有意差异）
  # - refresh: {sub, saas_refresh_token, typ=refresh, iss, iat, exp}（7d；
  #   SSO 链路内嵌 saas refresh token）
  # fail-fast：JWT_SIGNING_KEY 缺/弱（<32B）直接 raise 阻断（suite-hard-rules §1）。
  class TokenService
    TYP_ACCESS = 'access'
    TYP_REFRESH = 'refresh'

    def initialize(
      signing_key: ENV.fetch('JWT_SIGNING_KEY'),
      issuer: ENV.fetch('JWT_ISSUER'),
      access_ttl: ENV.fetch('JWT_TTL_SECONDS').to_i,
      refresh_ttl: ENV.fetch('JWT_REFRESH_TTL_SECONDS').to_i
    )
      raise ArgumentError, 'JWT_SIGNING_KEY must be >=32 bytes' if signing_key.length < 32

      @signing_key = signing_key
      @issuer = issuer
      @access_ttl = access_ttl
      @refresh_ttl = refresh_ttl
    end

    def issue_access(user_id, tenant_id)
      now = Time.now.to_i
      claims = { sub: user_id, iat: now, exp: now + @access_ttl, typ: TYP_ACCESS, iss: @issuer }
      claims[:tenant_id] = tenant_id if tenant_id.present?
      JWT.encode(claims, @signing_key, 'HS256')
    end

    def issue_refresh(user_id, saas_refresh_token)
      now = Time.now.to_i
      JWT.encode(
        { sub: user_id, saas_refresh_token: saas_refresh_token, iat: now,
          exp: now + @refresh_ttl, typ: TYP_REFRESH, iss: @issuer },
        @signing_key, 'HS256'
      )
    end

    # 验签 + exp/iss/typ 校验。无效抛 JWT::* —— 调用方（JwtGuard）统一转 401。
    # 返回 payload（sub / tenant_id / typ / ...）。
    def verify!(token, typ: TYP_ACCESS)
      decoded, = JWT.decode(
        token, @signing_key, true,
        algorithm: 'HS256', iss: @issuer,
        verify_expiration: true, verify_iss: true
      )
      raise JWT::InvalidPayloadError, "unexpected typ: #{decoded['typ']}" unless decoded['typ'] == typ

      decoded
    end
  end
end
