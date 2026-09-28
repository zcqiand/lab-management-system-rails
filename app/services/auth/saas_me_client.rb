# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Auth
  # saas /me 系真对接（lab-springboot SaasMeClient 镜像）：
  # /api/v1/me、/me/tenants、/me/menus（Map<appCode, tree>）、/admin/tenants（显示名富化）。
  # 401/4xx→InvalidGrant；5xx+网络→UpstreamUnavailable（同 SaasAuthClient 分流）。
  class SaasMeClient
    InvalidGrant = SaasAuthClient::InvalidGrant
    UpstreamUnavailable = SaasAuthClient::UpstreamUnavailable

    def initialize(saas_base: ENV.fetch('LAB_SAAS_BASE_URL'))
      @saas_base = saas_base.chomp('/')
    end

    # 返回 {id, email, displayName, memberships, currentTenantId}
    def whoami(saas_access_token)
      get_json('/api/v1/me', saas_access_token)
    end

    def list_my_tenants(saas_access_token)
      get_json('/api/v1/me/tenants', saas_access_token) || []
    end

    # saas /me/menus 返 Map<appCode, List<EffectiveMenuNode>>，按 appCode 取子树
    def list_my_menus(saas_access_token, app_code)
      map = get_json('/api/v1/me/menus', saas_access_token)
      return [] if map.blank?

      map[app_code] || []
    end

    # 平台租户列表（display-name 富化；分页壳 {items,total}）
    def list_platform_tenants(saas_access_token)
      page = get_json('/api/v1/admin/tenants?page=0&pageSize=100', saas_access_token)
      page.nil? || page['items'].nil? ? [] : page['items']
    end

    private

    def get_json(path_with_query, token)
      uri = URI("#{@saas_base}#{path_with_query}")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(Net::HTTP::Get.new(uri, 'Authorization' => "Bearer #{token}"))
      end
      case res.code.to_i
      when 200..299 then res.body.present? ? JSON.parse(res.body) : nil
      when 400..499 then raise InvalidGrant, "saas #{res.code} #{truncate(res.body)}"
      else raise UpstreamUnavailable, "saas #{res.code}"
      end
    rescue SocketError, Errno::ECONNREFUSED, Timeout::Error => e # Timeout::Error 含 Net::OpenTimeout
      raise UpstreamUnavailable, "saas connect failed: #{e.message}"
    end

    def truncate(s, max = 200)
      return '' if s.nil?

      s.length <= max ? s : "#{s[0, max]}..."
    end
  end
end
