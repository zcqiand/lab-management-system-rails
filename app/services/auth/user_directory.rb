# frozen_string_literal: true

module Auth
  # 配置式 demo 目录（lab-springboot ConfigUserDirectory 1:1 镜像）。
  # lab 库无身份表：用户/租户在内存（数据镜像 lab-msw seeds）。
  # - 用户：alice / dev123456（USER-A, roleCode=admin），口令读 LAB_AUTH_DEV_PASSWORD
  #   （ADR-0019 禁字面默认值，fail-fast）
  # - 租户：TENANT-001 city-lab / TENANT-002 district-lab / TENANT-003 third-party
  # - SSO 用户 upsert 进内存；per-user saas refresh token（rotate-once reload 用）
  class UserDirectory
    CurrentUser = Struct.new(:id, :username, :display_name, :role_code, keyword_init: true)
    MyTenant = Struct.new(:tenant_id, :code, :name, :role_ids, keyword_init: true)

    TENANTS = [
      MyTenant.new(tenant_id: 'TENANT-001', code: 'city-lab', name: '市住建工程质量检测中心',
                   role_ids: ['admin']),
      MyTenant.new(tenant_id: 'TENANT-002', code: 'district-lab', name: '区检测站',
                   role_ids: ['technician']),
      MyTenant.new(tenant_id: 'TENANT-003', code: 'third-party', name: '第三方检测实验室',
                   role_ids: ['viewer'])
    ].freeze

    def initialize(dev_password: ENV.fetch('LAB_AUTH_DEV_PASSWORD'))
      raise ArgumentError, 'LAB_AUTH_DEV_PASSWORD must not be blank (ADR-0019)' if dev_password.blank?

      @dev_password = dev_password
      @demo_user = CurrentUser.new(id: 'USER-A', username: 'alice', display_name: '管理员',
                                   role_code: 'admin')
      @upserted = {} # email => CurrentUser
      @saas_refresh_tokens = {} # user_id => saas refresh token
    end

    def find_by_username(username)
      return @demo_user if username == @demo_user.username

      @upserted.values.find { |u| u.username == username }
    end

    def find_by_email(email)
      # ADR-0008 username/email 桥接：SSO 回查按 email，demo 用户 username 即命中
      return @demo_user if email == @demo_user.username

      @upserted.values.find { |u| u.username == email }
    end

    def find_by_id(id)
      return @demo_user if id == @demo_user.id

      @upserted.values.find { |u| u.id == id }
    end

    def check_password?(username, password)
      @demo_user.username == username && @dev_password == password
    end

    def tenants_of(_username)
      TENANTS
    end

    def default_tenant
      TENANTS.first
    end

    def find_by_tenant_id(tenant_id)
      TENANTS.find { |t| t.tenant_id == tenant_id }
    end

    # 首次 SSO 落地 upsert（内存实现；V014+ 换 DB 实现时接口不变）
    def upsert(id, email, display_name, role_code)
      @upserted[email] ||= CurrentUser.new(
        id: id, username: email, display_name: display_name,
        role_code: role_code.present? ? role_code : 'viewer'
      )
    end

    def set_saas_refresh_token(user_id, token)
      return if user_id.blank? || token.blank?

      @saas_refresh_tokens[user_id] = token
    end

    def get_saas_refresh_token(user_id)
      return nil if user_id.blank?

      @saas_refresh_tokens[user_id]
    end
  end
end
