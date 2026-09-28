# frozen_string_literal: true

require 'test_helper'
require_relative '../support/business_helpers'

# M03.F02/F03 样品域集成测试（行为真源 = lab-springboot SampleService/SampleMapper +
# lab-ct samples(.write).test.ts，含 M03.F01.I07 ext 补录 5.89 锁定断言）。
class SamplesApiTest < ActionDispatch::IntegrationTest
  include BusinessApiTest

  def setup
    super
    @report_name = create_report_name
    @contract_id = create_contract_api
    @receipt_id = create_receipt_api(@contract_id, @report_name.code)
  end

  test '缺 Bearer token → 401' do
    get '/api/samples'
    assert_response :unauthorized
  end

  test 'create → 200 + id S- 前缀 + ext 回显；receipt FK 缺失 → 404 NSEE 语义' do
    api_post('/api/samples', { receiptId: @receipt_id, sampleCode: 'SMP-1', sampleName: '试块',
                               ext: { 'level' => 'P6' } })
    assert_response :success
    created = parsed
    assert_match(/\AS-[\da-f-]{36}\z/, created['id'])
    assert_equal 'SMP-1', created['sampleCode']
    assert_equal({ 'level' => 'P6' }, created['ext'])
    assert_equal tenant_id, created['tenantId']

    api_post('/api/samples', { receiptId: '00000000-0000-0000-0000-00000000dead',
                               sampleCode: 'SMP-X' })
    assert_response :not_found
    assert_match(/Receipt not found/, parsed['message'])
  end

  test 'list envelope page=1/pageSize=20 + receiptId/keyword 过滤' do
    id = create_sample_api
    api_get('/api/samples')
    assert_response :success
    envelope = parsed
    %w[items page pageSize total].each { |k| assert envelope.key?(k), "缺 #{k}" }
    assert_equal 1, envelope['page']
    assert_equal 20, envelope['pageSize']

    api_get("/api/samples?receiptId=#{@receipt_id}")
    assert_response :success
    assert(parsed['items'].any? { |s| s['id'] == id })

    api_get('/api/samples?keyword=NO-SUCH-CODE')
    assert_response :success
    assert_empty parsed['items']
  end

  test 'tenant-scoping：异租户 token 列表不可见 + 详情 404' do
    id = create_sample_api
    api_get('/api/samples', other_tenant_id)
    assert_response :success
    refute(parsed['items'].any? { |s| s['id'] == id })

    api_get("/api/samples/#{id}", other_tenant_id)
    assert_response :not_found
  end

  test 'PUT 更新 sampleName；sampleCode/receiptId 不在 Update 面不被改' do
    id = create_sample_api
    api_put("/api/samples/#{id}", { sampleName: '改名试块', sampleCode: 'HACKED' })
    assert_response :success
    assert_equal '改名试块', parsed['sampleName']
    assert_equal 'SMP-1', parsed['sampleCode']
  end

  test 'PUT ext：真实 sample 写入 → GET 回读一致（恒 404 退化必红口径）' do
    id = create_sample_api
    api_put("/api/samples/#{id}/ext", { ext: { 'ctProbe' => 'val-42' } })
    assert_response :success
    assert_equal({ 'ctProbe' => 'val-42' }, parsed['ext'])

    api_get("/api/samples/#{id}")
    assert_response :success
    assert_equal 'val-42', parsed.dig('ext', 'ctProbe')
  end

  test 'PUT ext 缺 ext 键 → 400 "ext is required"（5.89 契约必填锁定）' do
    id = create_sample_api
    api_put("/api/samples/#{id}/ext", {})
    assert_response :bad_request
    assert_match(/ext is required/, parsed['message'])
  end

  test 'PUT ext 查无 id → 404（ext 校验先于查无，springboot updateExt 镜像：带 ext 打死 id）' do
    api_put('/api/samples/00000000-0000-0000-0000-00000000dead/ext',
            { ext: { 'k' => 'v' } })
    assert_response :not_found
  end

  test 'DELETE → 204；重复删 → 404' do
    id = create_sample_api
    api_delete("/api/samples/#{id}")
    assert_response :no_content
    api_delete("/api/samples/#{id}")
    assert_response :not_found
  end

  private

  def create_sample_api
    api_post('/api/samples', { receiptId: @receipt_id, sampleCode: 'SMP-1' })
    assert_response :success
    parsed.fetch('id')
  end
end
