# frozen_string_literal: true

# 检测字典域集成测试共享助手（ARCHITECTURE §8）：
# - token 用 LabAuth::TokenService.issue_access 直签（Bearer typ=access）
# - 数据用 ActiveRecord 显式造，code 全部带随机后缀，防 lab_test 残留行串扰
# - 测试对 lab_test 真库跑（事务回滚），种子零归 shared seed 链独占
# 并行波次垫片：application_controller.rb 的 `rescue_from Auth::MenusUnavailable`
# 在 ApplicationController 首载时按常量名解析，而该常量定义在 auth_service.rb 文件尾
# （Zeitwerk 无 1:1 路径映射，懒加载必 NameError）—— 先显式触发 Auth::AuthService
# 装载。auth 波次把常量挪进自有文件后此行可删。
Auth::AuthService.name

module LabSupport
  TENANT_A = 'a0000000-0000-0000-0000-00000000000a'
  TENANT_B = 'b0000000-0000-0000-0000-00000000000b'

  module_function

  # Bearer access token（缺省租户 TENANT_A）
  def auth_header(tenant_id = TENANT_A)
    token = LabAuth::TokenService.new.issue_access('tester', tenant_id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def json(response)
    JSON.parse(response.body)
  end

  # 唯一业务码（每测试现场生成，落库行事务回滚，不依赖前后缀清理）
  def uniq_code(prefix)
    "#{prefix}-#{SecureRandom.hex(4)}"
  end

  # FK 锚点四件套：specialty/object/parameter/standard 各一行（互链满足全部 FK）
  def seed_dictionary!(prefix = 'tst')
    now = ApplicationRecord.now_iso
    specialty = InspectionSpecialty.create!(
      code: uniq_code("#{prefix}-sp"), official_no: "ON-#{prefix}", name: "专项#{prefix}",
      sort_order: 0, created_at: now, updated_at: now
    )
    object = InspectionObject.create!(
      code: uniq_code("#{prefix}-obj"), inspection_specialty_code: specialty.code,
      source_project_no: "P-#{prefix}", source_project_name: "项目#{prefix}", name: "对象#{prefix}",
      sort_order: 0, created_at: now, updated_at: now
    )
    parameter = InspectionParameter.create!(
      code: uniq_code("#{prefix}-ip"), name: "参数#{prefix}", raw_name: "raw-#{prefix}",
      canonical_name: "can-#{prefix}", aliases: [], sort_order: 0, created_at: now, updated_at: now
    )
    standard = InspectionStandard.create!(
      code: uniq_code("#{prefix}-std"), name: "标准#{prefix}", status: 'active',
      sort_order: 0, created_at: now, updated_at: now
    )
    { specialty: specialty, object: object, parameter: parameter, standard: standard }
  end
end
