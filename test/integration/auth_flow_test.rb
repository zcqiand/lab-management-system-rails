# frozen_string_literal: true

require 'test_helper'

# M00.F01/F02 + M01.F04/F05 认证域集成测试（镜像 lab-ct auth*.test.ts 断言口径 +
# lab-springboot AuthService 语义）。saas 上游用注入 stub（不真打 :5101）；
# 真链路对拍归 lab-ct live。
class AuthFlowTest < ActionDispatch::IntegrationTest
  MANAGED_TENANTS = [
    { 'tenantId' => 'ten-saas-1', 'roleIds' => ['r1'] },
    { 'tenantId' => 'ten-saas-2', 'roleIds' => [] }
  ].freeze
  PLATFORM_TENANTS = [
    { 'id' => 'ten-saas-1', 'name' => '市检测中心', 'tenantKey' => 'city' },
    { 'id' => 'ten-saas-2', 'name' => '区检测站', 'tenantKey' => 'district' }
  ].freeze
  SAAS_MENU_TREE = [
    { 'id' => 'm1', 'code' => 'dash', 'title' => '工作台', 'type' => 'group',
      'sortOrder' => 2, 'children' => [
        { 'id' => 'm11', 'code' => 'summary', 'title' => nil, 'type' => 'page',
          'sortOrder' => 1, 'children' => [] }
      ] },
    { 'id' => 'm0', 'code' => 'contract', 'title' => '合同', 'type' => 'page',
      'sortOrder' => 1, 'children' => [] }
  ].freeze

  def setup
    super
    Auth::AuthService.reset!
    @svc = Auth::AuthService.instance
    @svc.saas_auth.define_singleton_method(:service_login) do |_u, _p|
      Auth::SaasAuthClient::TokenResponse.new(access_token: 'saas-at', refresh_token: 'saas-rt',
                                              token_type: 'Bearer', expires_in: 3600)
    end
    @svc.saas_auth.define_singleton_method(:token) do |grant, code: nil, refresh_token: nil, redirect_uri: nil|
      @calls ||= []
      (@calls ||= []) << { grant: grant, code: code, refresh: refresh_token, redirect: redirect_uri }
      Auth::SaasAuthClient::TokenResponse.new(access_token: 'saas-at2', refresh_token: 'saas-rt2',
                                              token_type: 'Bearer', expires_in: 3600)
    end
    @svc.saas_me.define_singleton_method(:whoami) do |_t|
      { 'id' => 'saas-u1', 'email' => 'bob@lab.dev', 'displayName' => '鲍勃',
        'currentTenantId' => 'ten-saas-1' }
    end
    @svc.saas_me.define_singleton_method(:list_my_tenants) { |_t| MANAGED_TENANTS }
    @svc.saas_me.define_singleton_method(:list_my_menus) { |_t, _app| SAAS_MENU_TREE }
    @svc.saas_me.define_singleton_method(:list_platform_tenants) { |_t| PLATFORM_TENANTS }
  end

  def teardown
    Auth::AuthService.reset!
  end

  test 'M00.F01.I02 login success returns token pair, demo user and 3 tenants' do
    post '/api/auth/login', params: { username: 'alice', password: 'dev123456' }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body['token'].present?
    assert body['refreshToken'].present?
    assert_equal 'USER-A', body.dig('user', 'id')
    assert_equal 'alice', body.dig('user', 'username')
    assert_equal 3, body['tenants'].size
    assert_equal 'TENANT-001', body.dig('tenants', 0, 'tenantId')
  end

  test 'login wrong password is 401 INVALID_CREDENTIALS' do
    post '/api/auth/login', params: { username: 'alice', password: 'nope' }, as: :json
    assert_response :unauthorized
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(response.body)['code']
  end

  test 'login missing username is 400' do
    post '/api/auth/login', params: { username: '', password: 'x' }, as: :json
    assert_response :bad_request
  end

  test 'native login shares the same credential path' do
    post '/api/auth/native-login', params: { username: 'alice', password: 'dev123456' }, as: :json
    assert_response :success
    assert_equal 'USER-A', JSON.parse(response.body).dig('user', 'id')
  end

  test 'me without token is 401' do
    get '/api/auth/me'
    assert_response :unauthorized
  end

  test 'me with demo token returns directory tenants and default tenant' do
    get '/api/auth/me', headers: auth_header(access_token('USER-A'))
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'TENANT-001', body['currentTenantId']
    assert_equal 3, body['tenants'].size
    assert_equal 'city-lab', body.dig('tenants', 0, 'code')
  end

  test 'me with unknown sub is 401' do
    get '/api/auth/me', headers: auth_header(access_token('ghost'))
    assert_response :unauthorized
  end

  test 'permissions returns the 11-item demo set' do
    get '/api/auth/permissions', headers: auth_header(access_token('USER-A'))
    assert_response :success
    assert_equal 11, JSON.parse(response.body)['permissions'].size
  end

  test 'menus without snapshot is 503 MENUS_UNAVAILABLE (demo fallback removed)' do
    get '/api/auth/menus', headers: auth_header(access_token('USER-A'))
    assert_response :service_unavailable
    assert_equal 'MENUS_UNAVAILABLE', JSON.parse(response.body)['code']
  end

  test 'menus after login returns mapped snapshot sorted by sortOrder' do
    login_alice
    get '/api/auth/menus', headers: auth_header(access_token('USER-A'))
    assert_response :success
    tree = JSON.parse(response.body)
    assert_equal(%w[m0 m1], tree.map { |n| n['id'] })
    assert_equal '工作台', tree[1]['label']
    # title nil → code 回退；group 无 icon → resource 兜底
    child = tree[1]['children'].first
    assert_equal 'summary', child['label']
    assert_equal 'resource', tree[1]['icon']
  end

  test 'refresh rotates via saas and repopulates membership snapshot' do
    svc = @svc
    stub_token = LabAuth::TokenService.new.issue_refresh('saas-u1', 'old-saas-rt')
    post '/api/auth/refresh', params: { refreshToken: stub_token }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    # tenants 来自 saas memberships + 平台租户名富化（code=tenantKey, name=真名）
    assert_equal 'city', body.dig('tenants', 0, 'code')
    assert_equal '市检测中心', body.dig('tenants', 0, 'name')
    assert_equal 'saas-u1', body.dig('user', 'id')
    # me() 走 SSO 租户体系（快照命中），currentTenantId 取快照首项
    get '/api/auth/me', headers: auth_header(body['token'])
    assert_response :success
    me = JSON.parse(response.body)
    assert_equal 'ten-saas-1', me['currentTenantId']
    assert_equal 2, me['tenants'].size
    refute_equal stub_token, body['refreshToken']
    assert svc
  end

  test 'refresh with garbage token is 401' do
    post '/api/auth/refresh', params: { refreshToken: 'not-a-jwt' }, as: :json
    assert_response :unauthorized
  end

  test 'refresh with access-type token is 401' do
    post '/api/auth/refresh', params: { refreshToken: access_token('USER-A') }, as: :json
    assert_response :unauthorized
  end

  test 'refresh without saas_refresh_token claim is 401' do
    token = LabAuth::TokenService.new.issue_refresh('USER-A', '')
    post '/api/auth/refresh', params: { refreshToken: token }, as: :json
    assert_response :unauthorized
  end

  test 'sso authorize echoes caller redirect_uri and state (ADR-0019 no fallback)' do
    # query 参数名是 snake_case redirect_uri（OAuth RFC 6749 §4.1.1 惯例，
    # springboot AuthApi @RequestParam("redirect_uri") + contract-test 同款）。
    # 2026-09-29 live 实锤：读驼峰 redirectUri → ct 全参请求 400。
    get '/api/auth/sso/authorize',
        params: { response_type: 'code', client_id: 'lab-management',
                  redirect_uri: 'http://localhost:5203/login', state: 'csrf-123' }
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body['authorizeUrl'], 'redirect_uri=http%3A%2F%2Flocalhost%3A5203%2Flogin'
    assert_includes body['authorizeUrl'], 'state=csrf-123'
    assert_includes body['authorizeUrl'], 'client_id=lab-management'
    assert_equal 'csrf-123', body['state']
  end

  test 'sso authorize without redirect_uri is 400' do
    get '/api/auth/sso/authorize', params: { state: 'x' }
    assert_response :bad_request
  end

  test 'sso callback exchanges code, upserts user by email and enriches tenant names' do
    post '/api/auth/sso/callback',
         params: { code: 'one-time-code', redirectUri: 'http://localhost:5203/login' }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'saas-u1', body.dig('user', 'id')
    assert_equal 'bob@lab.dev', body.dig('user', 'username')
    assert_equal '市检测中心', body.dig('tenants', 0, 'name')
    # me() 走 SSO 体系：membership 快照命中（回调整时已填充）
    get '/api/auth/me', headers: auth_header(body['token'])
    assert_response :success
    assert_equal 'ten-saas-1', JSON.parse(response.body)['currentTenantId']
  end

  test 'switch tenant reissues token with target claim' do
    post '/api/auth/switch-tenant', params: { tenantId: 'TENANT-002' },
                                    headers: auth_header(access_token('USER-A')), as: :json
    assert_response :success
    body = JSON.parse(response.body)
    claims = LabAuth::TokenService.new.verify!(body['token'])
    assert_equal 'TENANT-002', claims['tenant_id']
    assert body['token'].present?
    assert body['refreshToken'].present?
  end

  test 'switch tenant unknown id is 404' do
    post '/api/auth/switch-tenant', params: { tenantId: 'TENANT-404' },
                                    headers: auth_header(access_token('USER-A')), as: :json
    assert_response :not_found
  end

  test 'logout is 204 with token and 401 without' do
    post '/api/auth/logout', headers: auth_header(access_token('USER-A')), as: :json
    assert_response :no_content
    post '/api/auth/logout', as: :json
    assert_response :unauthorized
  end

  private

  def login_alice
    post '/api/auth/login', params: { username: 'alice', password: 'dev123456' }, as: :json
    assert_response :success
    JSON.parse(response.body)
  end

  def access_token(sub, tenant_id = nil)
    LabAuth::TokenService.new.issue_access(sub, tenant_id)
  end

  def auth_header(token)
    { 'Authorization' => "Bearer #{token}" }
  end
end
