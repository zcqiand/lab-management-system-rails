# frozen_string_literal: true

# M02 合同（tenant 隔离，unique (tenant_id, contract_code)；id 形如 "C-<uuid>"）。
class Contract < ApplicationRecord
  self.table_name = 'contracts'
  self.primary_key = :id
end
