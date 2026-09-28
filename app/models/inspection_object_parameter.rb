# frozen_string_literal: true

# M04 对象×参数 junction（复合 PK，含 qualification_level）。
class InspectionObjectParameter < ApplicationRecord
  self.table_name = 'inspection_object_parameters'
  self.primary_key = %i[inspection_object_code inspection_parameter_code]
end
