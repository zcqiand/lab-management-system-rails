# frozen_string_literal: true

# M06 计算方法（复合 PK object × parameter；表 V017 由 rules 重命名，
# PK 约束名遗留 inspection_calculation_rules_pkey）。
class InspectionCalculationMethod < ApplicationRecord
  self.table_name = 'inspection_calculation_methods'
  self.primary_key = %i[inspection_object_code inspection_parameter_code]
end
