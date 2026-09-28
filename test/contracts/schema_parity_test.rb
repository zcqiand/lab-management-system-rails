# frozen_string_literal: true

require_relative '../test_helper'

# DB-First parity（ADR-0025 的 Rails 等价强制）：
# 模型 schema-less（列运行时从 information_schema 读），漂移风险收敛为
# 「table_name/主键拼错」，本测试连测试库 reflect 对账，拼错即红。
class SchemaParityTest < ActiveSupport::TestCase
  # uuid pk 业务表
  UUID_PK_MODELS = [Contract, SampleReceipt, Sample, TestRecord].freeze

  # code 主键字典表
  CODE_PK_MODELS = [
    InspectionBrand, InspectionGrade, InspectionModel, InspectionSpec,
    InspectionSpecialty, InspectionObject, InspectionParameter,
    InspectionStandard, InspectionReportName, InspectionParamInterface
  ].freeze

  # 复合主键 junction 表（无 id 列，drizzle 复合 pk）
  COMPOSITE = {
    'InspectionCalculationMethod' => %i[inspection_object_code inspection_parameter_code],
    'InspectionSpecialtyObject' => %i[inspection_specialty_code inspection_object_code],
    'InspectionObjectParameter' => %i[inspection_object_code inspection_parameter_code],
    'InspectionObjectStandard' => %i[inspection_object_code inspection_standard_code role],
    'InspectionStandardParameter' => %i[inspection_standard_code inspection_parameter_code],
    'InspectionObjectReportName' => %i[inspection_object_code report_name_code],
    'InspectionReportNameParameter' => %i[report_name_code inspection_parameter_code],
    'InspectionReportNameStandard' => %i[report_name_code inspection_standard_code role],
    'InspectionParamInterfaceLink' => %i[inspection_parameter_code param_interface_code],
    'InspectionTechnicalRequirement' =>
      %i[inspection_object_code inspection_parameter_code judgment_standard_code]
  }.freeze

  test 'every model maps to a real table with the declared pk columns' do
    (UUID_PK_MODELS + CODE_PK_MODELS + COMPOSITE.keys.map(&:constantize)).each do |klass|
      table = klass.table_name
      assert ActiveRecord::Base.connection.table_exists?(table),
             "#{klass} -> #{table} does not exist in test DB"

      pk_cols = COMPOSITE[klass.name] ||
                (UUID_PK_MODELS.include?(klass) ? %i[id] : %i[code])
      pk_cols.each do |col|
        assert klass.columns_hash.key?(col.to_s), "#{klass} missing pk column '#{col}'"
      end
    end
  end

  test 'business pk columns are text (lab id 前缀约定：C-/R-/S-/TR-<uuid>)' do
    UUID_PK_MODELS.each do |klass|
      assert_equal :text, klass.columns_hash['id']&.type,
                   "#{klass} pk column 'id' should be text（家族 id 前缀字符串，非 saas 的 uuid 型）"
    end
  end

  test 'models do not declare a rails schema (DB-First: no migrate/structure spill)' do
    assert_empty Dir[Rails.root.join('db/migrate/*.rb')],
                 'lab-rails 无 db/migrate（schema SSOT = shared src/db/schema.ts）'
  end
end
