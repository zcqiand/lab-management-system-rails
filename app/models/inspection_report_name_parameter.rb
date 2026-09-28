# frozen_string_literal: true

# M05 报告名×参数 junction（复合 PK）。
class InspectionReportNameParameter < ApplicationRecord
  self.table_name = 'inspection_report_name_parameters'
  self.primary_key = %i[report_name_code inspection_parameter_code]
end
