# frozen_string_literal: true

require 'test_helper'
require_relative '../support/business_helpers'

# M02.F01 合同域集成测试（行为真源 = lab-springboot ContractService/ContractMapper +
# lab-ct contracts.test.ts）。
class ContractsApiTest < ActionDispatch::IntegrationTest
  include BusinessApiTest

  test '缺 Bearer token → 401 INVALID_CREDENTIALS' do
    get '/api/contracts'
    assert_response :unauthorized
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(@response.body)['code']
  end

  test '无 tenant_id claim 的 token → 兜底 directory 默认租户 TENANT-001（非 saas GUID）' do
    # 家族镜像：springboot currentTenantIdOrDefaultStatic 兜底 directory.defaultTenant()
    # （TENANTS[0] = TENANT-001）。2026-09-29 live 实锤：rails 误兜 LAB_SAAS_DEFAULT_TENANT_ID
    # （saas 服务账号域的 GUID），create 回显 tenantId 与 nextjs/springboot 分叉。
    token = LabAuth::TokenService.new.issue_access('tester', nil)
    post '/api/contracts', params: contract_payload.to_json,
                           headers: { 'Authorization' => "Bearer #{token}",
                                      'Content-Type' => 'application/json' }

    assert_response :success
    assert_equal 'TENANT-001', parsed['tenantId']
  end

  test 'CRUD 全链：create 回显 camelCase + id C- 前缀；list envelope page=1/pageSize=20' do
    payload = contract_payload
    api_post('/api/contracts', payload)
    assert_response :success
    created = parsed
    assert_match(/\AC-[\da-f-]{36}\z/, created['id'])
    assert_equal payload[:contractCode], created['contractCode']
    assert_equal payload[:projectName], created['projectName']
    assert_equal 'active', created['status']
    assert_equal tenant_id, created['tenantId']
    assert created.key?('createdAt')
    assert created.key?('updatedAt')

    api_get('/api/contracts')
    assert_response :success
    envelope = parsed
    %w[items page pageSize total].each { |k| assert envelope.key?(k), "缺 #{k}" }
    assert_equal 1, envelope['page']
    assert_equal 20, envelope['pageSize']
    assert_instance_of Array, envelope['items']
    assert envelope['total'] >= 1
    assert(envelope['items'].any? { |c| c['id'] == created['id'] })
  end

  test 'keyword 过滤只命中 contractCode/projectName 含关键字的行' do
    id = create_contract_api
    api_get("/api/contracts?keyword=#{parsed_key_for(id)}")
    assert_response :success
    items = parsed['items']
    refute_empty items
    assert(items.all? { |c| c['id'] == id })
    assert_equal items.size, parsed['total']
  end

  test 'status 过滤：archived 命中、active 不含已归档行' do
    id = create_contract_api
    api_put("/api/contracts/#{id}", { status: 'archived' })
    assert_response :success
    assert_equal 'archived', parsed['status']

    api_get('/api/contracts?status=archived')
    assert_response :success
    assert(parsed['items'].any? { |c| c['id'] == id })

    api_get('/api/contracts?status=active')
    assert_response :success
    refute(parsed['items'].any? { |c| c['id'] == id })
  end

  test '非法 status 枚举值 → 400（springboot 枚举反序列化镜像）' do
    api_get('/api/contracts?status=bogus')
    assert_response :bad_request
  end

  test 'tenant-scoping：异租户 token 列表不可见 + 详情 404' do
    id = create_contract_api
    api_get('/api/contracts', other_tenant_id)
    assert_response :success
    refute(parsed['items'].any? { |c| c['id'] == id })

    api_get("/api/contracts/#{id}", other_tenant_id)
    assert_response :not_found
  end

  test '查无 id → 404 NOT_FOUND（含非 UUID 形态，NSEE 语义不按裸 UUID 启发式折叠）' do
    api_get('/api/contracts/00000000-0000-0000-0000-00000000dead')
    assert_response :not_found
    assert_equal 'NOT_FOUND', parsed['code']

    api_get('/api/contracts/not-a-real-id')
    assert_response :not_found
  end

  test 'PUT 局部更新：改 projectName 生效；contractCode 不在 Update 面不被改' do
    id = create_contract_api
    api_get("/api/contracts/#{id}")
    original_code = parsed['contractCode']

    api_put("/api/contracts/#{id}", { projectName: 'renamed-proj', contractCode: 'HACKED' })
    assert_response :success
    assert_equal 'renamed-proj', parsed['projectName']
    assert_equal original_code, parsed['contractCode']
  end

  test 'DELETE → 204；重复删 → 404' do
    id = create_contract_api
    api_delete("/api/contracts/#{id}")
    assert_response :no_content
    api_delete("/api/contracts/#{id}")
    assert_response :not_found
  end

  test '缺必填字段（contractCode）→ 400 约束违反' do
    api_post('/api/contracts', { clientUnit: 'u', projectName: 'p' })
    assert_response :bad_request
  end

  test '非法 status 建单 → 400（Jackson 枚举镜像）' do
    api_post('/api/contracts', contract_payload.merge(status: 'bogus'))
    assert_response :bad_request
  end

  private

  def parsed_key_for(id)
    api_get("/api/contracts/#{id}")
    assert_response :success
    parsed['contractCode']
  end
end
