# frozen_string_literal: true

# M04 对象×标准 junction（三元复合 PK：object × standard × role）。
class InspectionObjectStandard < ApplicationRecord
  self.table_name = 'inspection_object_standards'
  self.primary_key = %i[inspection_object_code inspection_standard_code role]
end
