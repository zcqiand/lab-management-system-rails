# frozen_string_literal: true

# M04 检测参数（全局字典）。
class InspectionParameter < ApplicationRecord
  self.table_name = 'inspection_parameters'
  self.primary_key = :code
end
