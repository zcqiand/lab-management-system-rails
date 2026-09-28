# frozen_string_literal: true

# M05 报告名×标准 junction（三元复合 PK：code × standard × role）。
class InspectionReportNameStandard < ApplicationRecord
  self.table_name = 'inspection_report_name_standards'
  self.primary_key = %i[report_name_code inspection_standard_code role]
end
