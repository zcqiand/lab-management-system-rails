# frozen_string_literal: true

# M03 样品（级联于接样单；ext jsonb；id 形如 "S-<uuid>"）。
class Sample < ApplicationRecord
  self.table_name = 'samples'
  self.primary_key = :id
end
