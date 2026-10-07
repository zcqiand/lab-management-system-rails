# frozen_string_literal: true

require 'test_helper'
require_relative '../support/business_helpers'

# M05 报告汇总 + 仪表盘统计集成测试（行为真源 = lab-springboot SummaryService；
# lab-ct summary.test.ts：summaryName/columns/rows + DashboardStats 9 段必填面）。
class SummaryApiTest < ActionDispatch::IntegrationTest
  include BusinessApiTest

  def setup
    super
    @contract = create_contract_ar
    @report_name = create_report_name(summary_name: '混凝土抗压强度')
    @pass_issued = create_receipt_ar(@contract, @report_name.code, tenant_id,
                                     flow_status: 'issuance', result: 'pass',
                                     report_code: 'RP-T-1', project_name: '工程甲')
    @fresh_receiving = create_receipt_ar(@contract, @report_name.code, tenant_id,
                                         flow_status: 'receiving', result: nil,
                                         test_start_date: Date.today.iso8601,
                                         project_name: '工程乙')
  end

  test '缺 Bearer token → 401' do
    get '/api/summary'
    assert_response :unauthorized
  end

  test 'GET /summary：summaryName/columns/rows 必填面 + 行内容渲染' do
    api_get('/api/summary')
    assert_response :success
    data = parsed
    assert_equal '报告汇总（ALL）', data['summaryName']
    assert_equal(%w[commissionCode categoryCode projectName flowStatus result reportCode],
                 data['columns'].map { |c| c['key'] })
    assert_equal(%w[委托编号 报告类别 工程名称 流程状态 结论 报告编号],
                 data['columns'].map { |c| c['label'] })

    row = data['rows'].find { |r| r['commissionCode'] == @pass_issued.commission_code }
    assert row, '汇总行应含自建单'
    assert_equal 'issuance', row['flowStatus']
    assert_equal 'pass', row['result']
    assert_equal 'RP-T-1', row['reportCode']
    assert_equal '工程甲', row['projectName']
  end

  test 'GET /summary categoryCode 过滤 + 空串归 ALL' do
    api_get("/api/summary?categoryCode=#{@report_name.code}")
    assert_response :success
    assert_equal "报告汇总（#{@report_name.code}）", parsed['summaryName']
    assert(parsed['rows'].any? { |r| r['commissionCode'] == @pass_issued.commission_code })

    api_get('/api/summary?categoryCode=RN-NO-SUCH')
    assert_response :success
    assert_empty parsed['rows']
  end

  test 'GET /summary dateFrom/dateTo 走 commissionDate 字典序前缀匹配' do
    api_get('/api/summary?dateFrom=2026-09-21')
    assert_response :success
    refute(parsed['rows'].any? { |r| r['commissionCode'] == @pass_issued.commission_code })

    api_get('/api/summary?dateFrom=2026-09-01&dateTo=2026-09-30')
    assert_response :success
    assert(parsed['rows'].any? { |r| r['commissionCode'] == @pass_issued.commission_code })
  end

  test 'GET /summary/stats：9 段必填面 + 计数随自建行收敛' do
    api_get('/api/summary/stats')
    assert_response :success
    before = parsed

    create_receipt_ar(@contract, @report_name.code, tenant_id,
                      flow_status: 'archived', result: 'pass', report_code: 'RP-T-2')

    api_get('/api/summary/stats')
    assert_response :success
    after = parsed

    assert_stats_face(after)

    assert_equal before['receiptCount'] + 1, after['receiptCount']
    assert_equal before.dig('reportCountByStatus', 'issued') + 1,
                 after.dig('reportCountByStatus', 'issued')
    assert_equal before.dig('funnelByStage', 'issued') + 1,
                 after.dig('funnelByStage', 'issued')
    assert_equal before.dig('qualifiedRateByMaterial', 'concrete', 'pass') + 1,
                 after.dig('qualifiedRateByMaterial', 'concrete', 'pass'),
                 '材料合格率 pass 只计 result=pass 行'
    assert after['todayTestCount'] >= 1, 'todayTestCount 应计入 test_start_date=今天 的单'
  end

  test 'GET /summary/stats tenant-scoping：异租户看不到自建行' do
    api_get('/api/summary/stats', other_tenant_id)
    assert_response :success
    stats = parsed
    assert_equal 0, stats['receiptCount']
    assert_equal 0, stats.dig('reportCountByStatus', 'issued')
  end

  test 'M05.F01.I03 核心指标：今日试验数/报告产出/材料合格率走码表 summaryName' do
    fn 'M05.F01.I03'
    api_get('/api/summary/stats')
    assert_response :success
    before = parsed

    # 一张单同时驱动四段：issuance + result=pass + report_code + created_at=今天
    create_receipt_ar(@contract, @report_name.code, tenant_id,
                      flow_status: 'issuance', result: 'pass', report_code: 'RP-T-9')

    api_get('/api/summary/stats')
    assert_response :success
    after = parsed

    assert_equal before['todayTestCount'] + 1, after['todayTestCount'],
                 '新建单 created_at=今天 → 今日试验数 +1'
    assert_equal before.dig('reportOutputByStatus', 'generated') + 1,
                 after.dig('reportOutputByStatus', 'generated'), '有 report_code → 已生成 +1'
    assert_equal before.dig('reportOutputByStatus', 'issued') + 1,
                 after.dig('reportOutputByStatus', 'issued'), 'issuance → 已签发 +1'
    assert_equal before.dig('qualifiedRateByMaterial', 'concrete', 'total') + 1,
                 after.dig('qualifiedRateByMaterial', 'concrete', 'total'),
                 '码表 summaryName 含「混凝土」→ concrete 桶 total +1'
    assert_equal before.dig('qualifiedRateByMaterial', 'concrete', 'pass') + 1,
                 after.dig('qualifiedRateByMaterial', 'concrete', 'pass'),
                 'result=pass → concrete 桶 pass +1'
  end

  test 'M05.F01.I04 任务漏斗：六段拆分 data_entry 按 report_code 分段' do
    fn 'M05.F01.I04'
    api_get('/api/summary/stats')
    assert_response :success
    before = parsed['funnelByStage']

    # 六种状态各一张 → 六段各 +1（data_entry 有/无 report_code 分 reporting/testing）
    create_receipt_ar(@contract, @report_name.code, tenant_id, flow_status: 'receiving')
    create_receipt_ar(@contract, @report_name.code, tenant_id, flow_status: 'task_assignment')
    create_receipt_ar(@contract, @report_name.code, tenant_id,
                      flow_status: 'data_entry', report_code: nil)
    create_receipt_ar(@contract, @report_name.code, tenant_id,
                      flow_status: 'data_entry', report_code: 'RP-T-9')
    create_receipt_ar(@contract, @report_name.code, tenant_id, flow_status: 'review')
    create_receipt_ar(@contract, @report_name.code, tenant_id, flow_status: 'issuance')

    api_get('/api/summary/stats')
    assert_response :success
    f = parsed['funnelByStage']
    { 'pending_collect' => 'receiving', 'received' => 'task_assignment',
      'testing' => 'data_entry 无 report_code', 'reporting' => 'data_entry 有 report_code',
      'reviewing' => 'review', 'issued' => 'issuance' }.each do |stage, why|
      assert_equal before[stage] + 1, f[stage], "#{stage} 应 +1（#{why}）"
    end
  end

  private

  # DashboardStats 9 段必填面（M05.F01.I03/I04）
  def assert_stats_face(stats)
    %w[contractCount receiptCount sampleCount reportCountByStatus pendingTaskCount
       todayTestCount qualifiedRateByMaterial reportOutputByStatus funnelByStage].each do |k|
      assert stats.key?(k), "缺 #{k}"
    end
    %w[draft reviewing issued].each { |k| assert stats['reportCountByStatus'].key?(k) }
    %w[generated pending issued].each { |k| assert stats['reportOutputByStatus'].key?(k) }
    %w[concrete rebar sand].each do |mat|
      %w[total pass rate].each do |k|
        assert stats['qualifiedRateByMaterial'][mat].key?(k),
               "qualifiedRateByMaterial.#{mat} 缺 #{k}"
      end
    end
    %w[pending_collect received testing reporting reviewing issued].each do |k|
      assert stats['funnelByStage'].key?(k), "funnelByStage 缺 #{k}"
    end
  end
end
