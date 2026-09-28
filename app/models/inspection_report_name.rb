# frozen_string_literal: true

# M05 报告名称（全局字典）。
class InspectionReportName < ApplicationRecord
  self.table_name = 'inspection_report_names'
  self.primary_key = :code
end
