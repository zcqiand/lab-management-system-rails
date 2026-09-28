# frozen_string_literal: true

# 业务域（contracts/samples/receipts/test-records/summary）集成测试公共件。
# test_helper.rb 是硬边界不可改 —— 各测试文件 require_relative 本件后 include。
# token 直签口径：LabAuth::TokenService#issue_access（ARCHITECTURE.md §8）。

# application_controller.rb 的 auth 域 rescue_from 引用 Auth::MenusUnavailable 等
# 常量，它们内联定义在 auth_service.rb（zeitwerk 不映射内联常量）—— 控制器惰性加载
# 早于 AuthService 任何引用时会 NameError。此处显式触发加载垫序；auth 波次未就位时静默。
begin
  Auth::AuthService
rescue NameError
  nil
end

module BusinessApiTest
  def tenant_id
    ENV.fetch('LAB_SAAS_DEFAULT_TENANT_ID')
  end

  # 异租户 id（只用于 tenant-scoping 断言，库里无需真实租户行 —— tenant_id 是裸 text 列）
  def other_tenant_id
    '11111111-1111-1111-1111-111111111111'
  end

  def auth_headers(tid = tenant_id)
    token = LabAuth::TokenService.new.issue_access('tester', tid)
    { 'Authorization' => "Bearer #{token}" }
  end

  def json_headers(tid = tenant_id)
    auth_headers(tid).merge('Content-Type' => 'application/json')
  end

  def api_get(path, tid = tenant_id)
    get path, headers: auth_headers(tid)
  end

  def api_post(path, payload, tid = tenant_id)
    post path, params: payload.to_json, headers: json_headers(tid)
  end

  def api_put(path, payload, tid = tenant_id)
    put path, params: payload.to_json, headers: json_headers(tid)
  end

  def api_patch(path, payload, tid = tenant_id)
    patch path, params: payload.to_json, headers: json_headers(tid)
  end

  def api_delete(path, tid = tenant_id)
    delete path, headers: auth_headers(tid)
  end

  # act body：operator 传 :missing 表示整个键缺失（对照 ct operator 缺失/空串两形态）
  def act_body(receipt_id, action, operator: 'tester-op', reason: nil)
    payload = { ids: [receipt_id], action: action }
    payload[:operator] = operator unless operator == :missing
    payload[:reason] = reason if reason
    payload
  end

  def act(stage, receipt_id, action, **)
    api_post("/api/receipts/#{stage}/act", act_body(receipt_id, action, **))
    assert_response :success
    JSON.parse(@response.body)
  end

  def parsed
    JSON.parse(@response.body)
  end

  # ── 字典父行显式造（FK 依赖：receipts.category_code → inspection_report_names.code、
  #    test_records.parameter_code → inspection_parameters.code；不依赖字典波次代码）──
  def create_report_name(summary_name: '混凝土抗压强度')
    now = ApplicationRecord.now_iso
    InspectionReportName.create!(
      code: "RN-T-#{SecureRandom.hex(4)}", name: "报告名-#{SecureRandom.hex(3)}",
      summary_name: summary_name, created_at: now, updated_at: now
    )
  end

  def create_parameter
    now = ApplicationRecord.now_iso
    InspectionParameter.create!(
      code: "IP-T-#{SecureRandom.hex(4)}", name: "参数-#{SecureRandom.hex(3)}",
      raw_name: 'raw', canonical_name: 'canonical', created_at: now, updated_at: now
    )
  end

  def create_contract_ar(tid = tenant_id)
    now = ApplicationRecord.now_iso
    Contract.create!(
      id: "C-#{SecureRandom.uuid}", tenant_id: tid, contract_code: "CT-T-#{SecureRandom.hex(4)}",
      client_unit: 'unit', project_name: 'proj', construction_unit: 'cons',
      witness_unit: 'wu', witness: 'w', status: 'active', created_at: now, updated_at: now
    )
  end

  def create_receipt_ar(contract, category_code, tid = tenant_id, attrs = {})
    now = ApplicationRecord.now_iso
    SampleReceipt.create!(
      attrs.reverse_merge(
        id: "R-#{SecureRandom.uuid}", tenant_id: tid, contract_id: contract.id,
        commission_code: "WT-T-#{SecureRandom.hex(4)}", commission_date: '2026-09-20',
        category_code: category_code, received_by: 'alice', sample_source: 'client',
        test_category: 'concrete', flow_status: 'receiving', flow_history: [], result: '',
        created_at: now, updated_at: now
      )
    )
  end

  def contract_payload(suffix = SecureRandom.hex(4))
    { contractCode: "CT-T-#{suffix}", clientUnit: "unit-#{suffix}", projectName: "proj-#{suffix}",
      constructionUnit: "cons-#{suffix}", witnessUnit: "wu-#{suffix}", witness: "w-#{suffix}" }
  end

  def create_contract_api(tid = tenant_id)
    api_post('/api/contracts', contract_payload, tid)
    assert_response :success
    parsed.fetch('id')
  end

  def receipt_payload(contract_id, category_code, suffix = SecureRandom.hex(4))
    { contractId: contract_id, commissionCode: "WT-T-#{suffix}", commissionDate: '2026-09-20',
      categoryCode: category_code, receivedBy: 'alice', sampleSource: 'client',
      testCategory: 'concrete' }
  end

  def create_receipt_api(contract_id, category_code, tid = tenant_id)
    api_post('/api/receipts', receipt_payload(contract_id, category_code), tid)
    assert_response :success
    parsed.fetch('id')
  end
end
