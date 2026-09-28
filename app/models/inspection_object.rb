# frozen_string_literal: true

# M04 检测对象（全局字典）。表 inspection_objects，PK code。
class InspectionObject < ApplicationRecord
  self.table_name = 'inspection_objects'
  self.primary_key = :code
end
