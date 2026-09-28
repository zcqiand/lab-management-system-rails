# frozen_string_literal: true

# M10 参数接口（全局；PK 约束名遗留 param_interfaces_pkey）。
class InspectionParamInterface < ApplicationRecord
  self.table_name = 'inspection_param_interfaces'
  self.primary_key = :code
end
