# frozen_string_literal: true

# M04 检测对象字典：grade（tenant 隔离，unique (tenant_id, code) —— code 是全局
# PK 列但家族约定按 tenant 过滤后寻址，镜像 lab-springboot CatalogService）。
class InspectionGrade < ApplicationRecord
  self.table_name = 'inspection_grades'
  self.primary_key = :code
end
