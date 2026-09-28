# frozen_string_literal: true

# M05 对象×报告名 junction（复合 PK）。
class InspectionObjectReportName < ApplicationRecord
  self.table_name = 'inspection_object_report_names'
  self.primary_key = %i[inspection_object_code report_name_code]
end
