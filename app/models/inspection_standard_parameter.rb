# frozen_string_literal: true

# M04 标准×参数 junction（复合 PK）。
class InspectionStandardParameter < ApplicationRecord
  self.table_name = 'inspection_standard_parameters'
  self.primary_key = %i[inspection_standard_code inspection_parameter_code]
end
