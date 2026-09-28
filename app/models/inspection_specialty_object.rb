# frozen_string_literal: true

# M04 专业×对象 junction（复合 PK）。
class InspectionSpecialtyObject < ApplicationRecord
  self.table_name = 'inspection_specialty_objects'
  self.primary_key = %i[inspection_specialty_code inspection_object_code]
end
