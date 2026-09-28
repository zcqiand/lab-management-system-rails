# frozen_string_literal: true

require 'test_helper'
require_relative '../support/business_helpers'

# M03.F01-F09 接样单域集成测试（行为真源 = lab-springboot SampleReceiptService +
# ReportFlowService + SampleReceiptMapper；lab-ct sample-receipts(.write).test.ts、
# receipts-act(.test|.test.ts|-history|-lastsubmit).test.ts）。
class ReceiptsApiTest < ActionDispatch::IntegrationTest
  include BusinessApiTest

  def setup
    super
    @report_name = create_report_name
    @contract_id = create_contract_api
    @receipt_id = create_receipt_api(@contract_id, @report_name.code)
  end

  test '缺 Bearer token → 401' do
    get '/api/receipts'
    assert_response :unauthorized
  end

  test 'create → 200 + id R- 前缀 + 初始态 receiving/空 history/空 result' do
    created = parsed_receipt(@receipt_id)
    assert_match(/\AR-[\da-f-]{36}\z/, created['id'])
    assert_equal 'receiving', created['flowStatus']
    assert_empty created['flowHistory']
    assert_equal '', created['result']
    assert_equal @contract_id, created['contractId']
    assert_equal tenant_id, created['tenantId']
  end

  test 'create contract FK 缺失 → 404 NSEE 语义' do
    api_post('/api/receipts', receipt_payload('00000000-0000-0000-0000-00000000dead',
                                              @report_name.code))
    assert_response :not_found
    assert_match(/Contract not found/, parsed['message'])
  end

  test 'list envelope page=1/pageSize=20 + contractId/keyword/flowStatus 过滤' do
    api_get('/api/receipts')
    assert_response :success
    envelope = parsed
    %w[items page pageSize total].each { |k| assert envelope.key?(k), "缺 #{k}" }
    assert_equal 1, envelope['page']
    assert_equal 20, envelope['pageSize']

    api_get("/api/receipts?contractId=#{@contract_id}")
    assert_response :success
    assert(parsed['items'].any? { |r| r['id'] == @receipt_id })

    api_get('/api/receipts?keyword=NO-SUCH-COMMISSION')
    assert_response :success
    assert_empty parsed['items']

    api_get('/api/receipts?flowStatus=receiving')
    assert_response :success
    assert(parsed['items'].any? { |r| r['id'] == @receipt_id })

    api_get('/api/receipts?flowStatus=archived')
    assert_response :success
    refute(parsed['items'].any? { |r| r['id'] == @receipt_id })

    api_get('/api/receipts?flowStatus=bogus')
    assert_response :bad_request
  end

  test 'filter 三态：not_yet/submitted 互斥，submit 后 submitted 命中并写 lastSubmittedBy' do
    api_get('/api/receipts?filter=not_yet&pageSize=500')
    assert_response :success
    hit = parsed['items'].find { |r| r['id'] == @receipt_id }
    assert hit, '新单应命中 not_yet'
    assert_empty hit['flowHistory']

    result = act('receiving', @receipt_id, 'submit')
    assert result.first['ok']
    assert_equal 'task_assignment', result.first['flowStatus']

    api_get('/api/receipts?filter=submitted&pageSize=500')
    assert_response :success
    hit = parsed['items'].find { |r| r['id'] == @receipt_id }
    assert hit, 'submit 后应命中 submitted'
    assert_equal 'tester-op', hit['lastSubmittedBy']

    api_get('/api/receipts?filter=not_yet&pageSize=500')
    assert_response :success
    refute parsed['items'].any? { |r| r['id'] == @receipt_id }, '已提交单不应再命中 not_yet'
  end

  test 'tenant-scoping：异租户 token 列表不可见 + 详情 404' do
    api_get('/api/receipts', other_tenant_id)
    assert_response :success
    refute(parsed['items'].any? { |r| r['id'] == @receipt_id })

    api_get("/api/receipts/#{@receipt_id}", other_tenant_id)
    assert_response :not_found
  end

  test 'history：新单空数组；submit 后条目记 action/from/to/operator 真值' do
    api_get("/api/receipts/#{@receipt_id}/history")
    assert_response :success
    assert_empty parsed

    act('receiving', @receipt_id, 'submit')
    api_get("/api/receipts/#{@receipt_id}/history")
    assert_response :success
    entry = parsed.last
    assert_equal 'submit', entry['action']
    assert_equal 'receiving', entry['from']
    assert_equal 'task_assignment', entry['to']
    assert_equal 'tester-op', entry['operator']

    api_get('/api/receipts/00000000-0000-0000-0000-00000000dead/history')
    assert_response :not_found
  end

  test '5.75 history action 真值：submit→return→withdraw 序列逐条落真值（不写字面量 submit）' do
    act('receiving', @receipt_id, 'submit')
    act('assigning', @receipt_id, 'return')
    assert_equal 'return', last_history_action

    act('receiving', @receipt_id, 'withdraw')
    assert_equal 'withdraw', last_history_action

    api_get("/api/receipts/#{@receipt_id}/history")
    assert parsed.any? { |e| e['action'] == 'submit' }, '首条 submit 条目不被串改'
  end

  test '5.69 lastSubmittedBy：submit 写操作人 / return 保留 / withdraw 清空' do
    act('receiving', @receipt_id, 'submit')
    assert_equal 'tester-op', parsed_receipt(@receipt_id)['lastSubmittedBy']

    act('assigning', @receipt_id, 'return')
    assert_equal 'tester-op', parsed_receipt(@receipt_id)['lastSubmittedBy'],
                 'return 保留原值'

    act('receiving', @receipt_id, 'withdraw')
    assert_nil parsed_receipt(@receipt_id)['lastSubmittedBy'], 'withdraw 清空'
  end

  test 'withdraw 仅 receiving 合法：其它阶段 → ok=false Invalid transition' do
    act('receiving', @receipt_id, 'submit')
    result = act('assigning', @receipt_id, 'withdraw')
    refute result.first['ok']
    assert_match(/Invalid transition/, result.first['message'])
    assert_equal 'task_assignment', parsed_receipt(@receipt_id)['flowStatus']
  end

  test 'assign_task：receiving → task_assignment + history "M03.F02 任务分配"；字段回显' do
    api_put("/api/receipts/#{@receipt_id}/task",
            { assigneeId: 'USER-A', assigneeName: '张三', plannedTestDate: '2026-10-01' })
    assert_response :success
    created = parsed
    assert_equal 'task_assignment', created['flowStatus']
    assert_equal 'USER-A', created['assigneeId']
    assert_equal '张三', created['assigneeName']
    assert_equal '2026-10-01', created['plannedTestDate']
    entry = created['flowHistory'].last
    assert_equal 'submit', entry['action']
    assert_equal 'M03.F02 任务分配', entry['reason']
    assert_equal '张三', entry['operator']
  end

  test 'assign_task：非 receiving 阶段只改字段不推进状态' do
    receipt2 = create_receipt_api(@contract_id, @report_name.code)
    act('receiving', receipt2, 'submit')
    api_put("/api/receipts/#{receipt2}/task", { assigneeName: '李四' })
    assert_response :success
    assert_equal 'task_assignment', parsed['flowStatus']
    assert_equal '李四', parsed['assigneeName']
  end

  test '7 态 submit 全链：receiving→…→archived 逐段推进，响应 ok+flowStatus' do
    chain = [%w[receiving task_assignment], %w[assigning data_entry], %w[data-entry review],
             %w[review approval], %w[approve issuance], %w[issuance archived]]
    chain.each do |(stage, next_stage)|
      result = act(stage, @receipt_id, 'submit')
      assert result.first['ok'], "#{stage} submit 应 ok：#{result.first['message']}"
      assert_equal next_stage, result.first['flowStatus']
      assert_equal next_stage, parsed_receipt(@receipt_id)['flowStatus']
    end
  end

  test 'stage mismatch → ok=false "Stage mismatch"（非法迁移不出 4xx，出 err 结果）' do
    result = act('review', @receipt_id, 'submit')
    refute result.first['ok']
    assert_equal 'Stage mismatch: requires review but is receiving', result.first['message']
  end

  test 'RETURN 链：assigning return → receiving，状态回退' do
    act('receiving', @receipt_id, 'submit')
    result = act('assigning', @receipt_id, 'return')
    assert result.first['ok']
    assert_equal 'receiving', result.first['flowStatus']
    assert_equal 'receiving', parsed_receipt(@receipt_id)['flowStatus']
  end

  test 'archived 仅接受 submit：submit 自转移写 audit history；return → err' do
    advance_to_archived(@receipt_id)

    result = act('archived', @receipt_id, 'submit', reason: nil)
    assert result.first['ok']
    assert_equal 'archived', result.first['flowStatus']
    api_get("/api/receipts/#{@receipt_id}/history")
    assert_equal 'archived: post-archive audit', parsed.last['reason']

    result = act('archived', @receipt_id, 'return')
    refute result.first['ok']
    assert_match(/Action not allowed/, result.first['message'])
  end

  test 'act 对不存在 id → 200 + err 结果（NSEE 被 per-id 捕获）' do
    result = act('receiving', '00000000-0000-0000-0000-00000000dead', 'submit')
    refute result.first['ok']
    assert_match(/Receipt not found/, result.first['message'])
  end

  test 'operator 契约必填：缺失与空串两形态都 400，空串 message "operator is required"' do
    api_post('/api/receipts/receiving/act',
             { ids: ['00000000-0000-0000-0000-00000000dead'], action: 'submit' })
    assert_response :bad_request

    api_post('/api/receipts/receiving/act',
             { ids: ['00000000-0000-0000-0000-00000000dead'], action: 'submit', operator: '' })
    assert_response :bad_request
    assert_match(/operator is required/, parsed['message'])
  end

  test 'PUT 局部更新 commissionCode/projectName；contractId 不在 Update 面' do
    api_put("/api/receipts/#{@receipt_id}", { projectName: 'renamed-proj',
                                              contractId: 'HACKED' })
    assert_response :success
    assert_equal 'renamed-proj', parsed['projectName']
    assert_equal @contract_id, parsed['contractId']
  end

  test 'DELETE → 204；重复删 → 404' do
    api_delete("/api/receipts/#{@receipt_id}")
    assert_response :no_content
    api_delete("/api/receipts/#{@receipt_id}")
    assert_response :not_found
  end

  private

  def parsed_receipt(id)
    api_get("/api/receipts/#{id}")
    assert_response :success
    parsed
  end

  def last_history_action
    api_get("/api/receipts/#{@receipt_id}/history")
    assert_response :success
    parsed.last['action']
  end

  def advance_to_archived(id)
    %w[receiving assigning data-entry review approve issuance archived].each do |stage|
      act(stage, id, 'submit')
    end
  end
end
