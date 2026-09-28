# frozen_string_literal: true

module Summary
  # M05 报告汇总 + 仪表盘统计（lab-springboot SummaryService 镜像）。
  # 按 tenant + categoryCode（'ALL' = 不过滤）过滤 sample_receipts，commissionDate
  # 字典序当日期序；stats = 3 总数 + 3 桶状态 + 任务计数 + 4 段扩展（M05.F01.I03/I04）。
  class SummaryService
    include MaterialRates

    CATEGORY_ALL = 'ALL'

    COLUMNS = [
      { key: 'commissionCode', label: '委托编号' }, { key: 'categoryCode', label: '报告类别' },
      { key: 'projectName', label: '工程名称' }, { key: 'flowStatus', label: '流程状态' },
      { key: 'result', label: '结论' }, { key: 'reportCode', label: '报告编号' }
    ].freeze

    def initialize(tenant_id)
      @tenant_id = tenant_id
    end

    def report_summary(category_code, date_from, date_to)
      rows = summary_scope(category_code, date_from, date_to)
      {
        summary_name: "报告汇总（#{category_of(category_code)}）",
        columns: COLUMNS,
        rows: rows.map { |r| render_row(r) }
      }
    end

    def dashboard_stats
      receipts = summary_scope(CATEGORY_ALL, nil, nil)
      contract_count = Contract.where(tenant_id: @tenant_id).count
      sample_count = Sample.where(tenant_id: @tenant_id).count
      counting = receipts.group_by(&:flow_status)

      {
        contractCount: contract_count,
        receiptCount: receipts.size,
        sampleCount: sample_count,
        reportCountByStatus: report_count_by_status(counting),
        pendingTaskCount: bucket(counting, 'task_assignment', 'data_entry', 'review'),
        todayTestCount: today_test_count(receipts),
        qualifiedRateByMaterial: qualified_rate_by_material(receipts),
        reportOutputByStatus: report_output_by_status(receipts, counting),
        funnelByStage: funnel_by_stage(receipts, counting)
      }
    end

    private

    def category_of(category_code)
      category_code.blank? ? CATEGORY_ALL : category_code
    end

    # 汇总查询：tenant + 可选 categoryCode（ALL = 不过滤）+ 可选 commissionDate 前后界
    # （YYYY-MM-DD 字典序 = 日期序，null 视作无界）；排序 commissionDate DESC, commissionCode
    def summary_scope(category_code, date_from, date_to)
      scope = SampleReceipt.where(tenant_id: @tenant_id)
      cat = category_of(category_code)
      scope = scope.where(category_code: cat) unless cat == CATEGORY_ALL
      scope = scope.where('commission_date >= ?', date_from.to_s) if date_from.present?
      scope = scope.where('commission_date <= ?', date_to.to_s) if date_to.present?
      scope.order(commission_date: :desc, commission_code: :asc)
    end

    # 3 桶：draft = 前 3 阶段 / reviewing = review+approval / issued = issuance+archived
    def report_count_by_status(counting)
      {
        draft: bucket(counting, 'receiving', 'task_assignment', 'data_entry'),
        reviewing: bucket(counting, 'review', 'approval'),
        issued: bucket(counting, 'issuance', 'archived')
      }
    end

    def bucket(counting, *stages)
      stages.sum { |s| counting.fetch(s, []).size }
    end

    # 今日试验：created_at 或 test_start_date 以今天开头（字符串前缀，镜像 Java startsWith）
    def today_test_count(receipts)
      today = Date.today.iso8601
      receipts.count do |r|
        r.created_at.to_s.start_with?(today) || r.test_start_date.to_s.start_with?(today)
      end
    end

    def report_output_by_status(receipts, counting)
      {
        generated: receipts.count { |r| !r.report_code.nil? },
        pending: bucket(counting, 'review', 'approval'),
        issued: bucket(counting, 'issuance', 'archived')
      }
    end

    # 6 段任务漏斗：testing/reporting 按 data_entry 是否已有 report_code 拆分
    def funnel_by_stage(_receipts, counting)
      data_entry = counting.fetch('data_entry', [])
      {
        pending_collect: bucket(counting, 'receiving'),
        received: bucket(counting, 'task_assignment'),
        testing: data_entry.count { |r| r.report_code.nil? },
        reporting: data_entry.count { |r| !r.report_code.nil? },
        reviewing: bucket(counting, 'review', 'approval'),
        issued: bucket(counting, 'issuance', 'archived')
      }
    end

    def render_row(r)
      {
        'commissionCode' => r.commission_code.to_s, 'categoryCode' => r.category_code.to_s,
        'projectName' => r.project_name.to_s, 'flowStatus' => r.flow_status.to_s,
        'result' => r.result.to_s, 'reportCode' => r.report_code.to_s
      }
    end
  end
end
