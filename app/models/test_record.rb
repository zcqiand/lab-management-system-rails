# frozen_string_literal: true

# M03 检测记录（级联于样品；verdict 判定；id 形如 "TR-<uuid>"）。
class TestRecord < ApplicationRecord
  self.table_name = 'test_records'
  self.primary_key = :id
end
