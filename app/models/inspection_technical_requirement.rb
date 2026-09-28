# frozen_string_literal: true

# M04.F05 技术要求（三元复合 PK：object × parameter × judgment_standard；tenant 隔离）。
class InspectionTechnicalRequirement < ApplicationRecord
  self.table_name = 'inspection_technical_requirements'
  self.primary_key = %i[inspection_object_code inspection_parameter_code judgment_standard_code]
end
