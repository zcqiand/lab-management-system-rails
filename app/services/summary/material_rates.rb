# frozen_string_literal: true

module Summary
  # 仪表盘「按材料类型合格率」段（lab-springboot SummaryService.qualifiedRateByMaterial
  # 镜像）：码表 summaryName 关键词归类 concrete/rebar/sand，rate 保留三位小数。
  module MaterialRates
    # summaryName → 材料类型映射（与 msw handlers-extra 同款语义，LinkedHashMap 序）
    MATERIAL_KEYWORDS = {
      'concrete' => %w[混凝土 水泥],
      'rebar' => %w[钢筋 钢材 焊接 机械连接 连接],
      'sand' => %w[砂 碎（卵）石 轻集料 颗粒级配]
    }.freeze

    # 按材料类型合格率：码表全量预载（summaryName 关键词归类），rate 三位小数
    def qualified_rate_by_material(receipts)
      summary_name_by_code = InspectionReportName.all.to_h { |rn| [rn.code, rn.summary_name.to_s] }
      total = { 'concrete' => 0, 'rebar' => 0, 'sand' => 0 }
      pass = { 'concrete' => 0, 'rebar' => 0, 'sand' => 0 }
      receipts.each do |r|
        mat = material_of(r.category_code, summary_name_by_code)
        next if mat.nil?

        total[mat] += 1
        pass[mat] += 1 if r.result == 'pass'
      end
      total.to_h do |mat, t|
        rate = t.positive? ? (pass.fetch(mat) * 1000.0 / t).round / 1000.0 : 0.0
        [mat, { total: t, pass: pass.fetch(mat), rate: rate }]
      end
    end

    private

    def material_of(category_code, summary_name_by_code)
      return nil if category_code.nil?

      summary_name = summary_name_by_code.fetch(category_code, '')
      MATERIAL_KEYWORDS.each do |mat, keywords|
        return mat if keywords.any? { |kw| summary_name.include?(kw) }
      end
      nil
    end
  end
end
