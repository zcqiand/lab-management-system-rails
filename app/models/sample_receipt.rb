# frozen_string_literal: true

# M03 接样单（tenant 隔离；flow_status 7 态机 + flow_history jsonb；id 形如 "R-<uuid>"）。
class SampleReceipt < ApplicationRecord
  self.table_name = 'sample_receipts'
  self.primary_key = :id
end
