# frozen_string_literal: true

# M04 判定/检测标准（全局字典）。
class InspectionStandard < ApplicationRecord
  self.table_name = 'inspection_standards'
  self.primary_key = :code
end
