# frozen_string_literal: true

require 'test_helper'
require_relative '../support/business_helpers'

# M03.F03 检测记录域集成测试（行为真源 = lab-springboot TestRecordService +
# TestRecordMapper；lab-ct test-records(.write).test.ts）。
class TestRecordsApiTest < ActionDispatch::IntegrationTest
  include BusinessApiTest

  def setup
    super
    @report_name = create_report_name
    @parameter = create_parameter
    @contract_id = create_contract_api
    @receipt_id = create_receipt_api(@contract_id, @report_name.code)
    @sample_id = create_sample_api(@receipt_id)
  end

  test '缺 Bearer token → 401' do
    get '/api/test-records'
    assert_response :unauthorized
  end

  test 'create → 200 + id TR- 前缀 + 字段回显；四必填缺失 → 400 IAE' do
    api_post('/api/test-records',
             { sampleId: @sample_id, parameterCode: @parameter.code,
               requirement: '≥30MPa', result: '25.1', verdict: 'fail' })
    assert_response :success
    created = parsed
    assert_match(/\ATR-[\da-f-]{36}\z/, created['id'])
    assert_equal @sample_id, created['sampleId']
    assert_equal @parameter.code, created['parameterCode']
    assert_equal 'fail', created['verdict']
    assert_equal tenant_id, created['tenantId']

    api_post('/api/test-records', { sampleId: @sample_id })
    assert_response :bad_request
    assert_match(/sampleId, parameterCode, requirement and result are required/, parsed['message'])
  end

  test 'create sample FK 缺失 → 400 约束违反' do
    api_post('/api/test-records',
             { sampleId: '00000000-0000-0000-0000-00000000dead',
               parameterCode: @parameter.code, requirement: 'r', result: 'x' })
    assert_response :bad_request
  end

  test 'create parameter FK 缺失 → 400 约束违反' do
    api_post('/api/test-records',
             { sampleId: @sample_id, parameterCode: 'IP-NO-SUCH', requirement: 'r', result: 'x' })
    assert_response :bad_request
  end

  test 'list envelope page=1/pageSize=20 + sampleId 过滤' do
    id = create_record_api
    api_get('/api/test-records')
    assert_response :success
    envelope = parsed
    %w[items page pageSize total].each { |k| assert envelope.key?(k), "缺 #{k}" }
    assert_equal 1, envelope['page']
    assert_equal 20, envelope['pageSize']
    assert(envelope['items'].any? { |t| t['id'] == id })

    api_get("/api/test-records?sampleId=#{@sample_id}")
    assert_response :success
    assert(parsed['items'].any? { |t| t['id'] == id })

    api_get('/api/test-records?sampleId=00000000-0000-0000-0000-00000000dead')
    assert_response :success
    assert_empty parsed['items']
  end

  test 'tenant-scoping：异租户 token 列表不可见 + 详情 404' do
    id = create_record_api
    api_get('/api/test-records', other_tenant_id)
    assert_response :success
    refute(parsed['items'].any? { |t| t['id'] == id })

    api_get("/api/test-records/#{id}", other_tenant_id)
    assert_response :not_found
  end

  test '查无 id → 404' do
    api_get('/api/test-records/00000000-0000-0000-0000-00000000dead')
    assert_response :not_found
    assert_equal 'NOT_FOUND', parsed['code']
  end

  test 'PUT 局部更新 result/requirement；sampleId 不在 Update 面' do
    id = create_record_api
    api_put("/api/test-records/#{id}", { result: '31.2', sampleId: 'HACKED' })
    assert_response :success
    assert_equal '31.2', parsed['result']
    assert_equal @sample_id, parsed['sampleId']
  end

  test 'PATCH verdict 人工改判 → 200 生效并回读一致' do
    id = create_record_api
    api_patch("/api/test-records/#{id}/verdict", { verdict: 'pass' })
    assert_response :success
    assert_equal 'pass', parsed['verdict']

    api_get("/api/test-records/#{id}")
    assert_response :success
    assert_equal 'pass', parsed['verdict']
  end

  test 'PATCH verdict 查无 id → 404' do
    api_patch('/api/test-records/00000000-0000-0000-0000-00000000dead/verdict',
              { verdict: 'pass' })
    assert_response :not_found
  end

  test 'DELETE → 204；重复删 → 404' do
    id = create_record_api
    api_delete("/api/test-records/#{id}")
    assert_response :no_content
    api_delete("/api/test-records/#{id}")
    assert_response :not_found
  end

  private

  def create_sample_api(receipt_id)
    api_post('/api/samples', { receiptId: receipt_id, sampleCode: 'SMP-1' })
    assert_response :success
    parsed.fetch('id')
  end

  def create_record_api
    api_post('/api/test-records',
             { sampleId: @sample_id, parameterCode: @parameter.code,
               requirement: '≥30MPa', result: '25.1' })
    assert_response :success
    parsed.fetch('id')
  end
end
