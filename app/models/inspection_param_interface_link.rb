# frozen_string_literal: true

# M10 参数接口 link（复合 PK parameter × interface）。
class InspectionParamInterfaceLink < ApplicationRecord
  self.table_name = 'inspection_param_interface_links'
  self.primary_key = %i[inspection_parameter_code param_interface_code]
end
