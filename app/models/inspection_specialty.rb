# frozen_string_literal: true

# M04 检测专业（全局字典，无租户列）。表 inspection_specialties，PK code。
class InspectionSpecialty < ApplicationRecord
  self.table_name = 'inspection_specialties'
  self.primary_key = :code
end
