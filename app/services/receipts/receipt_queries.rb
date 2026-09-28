# frozen_string_literal: true

module Receipts
  # 接样单列表查询谓词（lab-springboot SampleReceiptMapper 的 WHERE 镜像）：
  # keyword LIKE 与 5.57 三态 filter（not_yet/submitted，jsonb 谓词 native SQL）。
  module ReceiptQueries
    def filter_keyword(scope, keyword)
      keyword = keyword.to_s
      return scope if keyword.empty?

      like = "%#{keyword.downcase}%"
      scope.where('(LOWER(commission_code) LIKE :k OR LOWER(project_name) LIKE :k)', k: like)
    end

    # 三态 filter（5.57，SSOT = lab-nextjs db-queries.ts:53-58；JPQL 表达不了 jsonb
    # 谓词，参照实现走 native SQL —— 此处同款谓词镜像）：
    #   not_yet   = 停在本环节（无 flowStatus 时 = 无流转记录新单）
    #   submitted = 已从本环节 submit 至下一环节（无 flowStatus 时 = 有流转记录且
    #               last_submitted_by 非空）
    def filter_three_state(tenant_id, contract_id, stage, keyword, filter)
      contract_id = contract_id.to_s
      conds = <<~SQL
        (:tenant_id = '' OR tenant_id = :tenant_id)
        AND (:contract_id = '' OR contract_id = :contract_id)
        AND (:keyword = '' OR LOWER(commission_code) LIKE '%' || LOWER(:keyword) || '%'
             OR LOWER(project_name) LIKE '%' || LOWER(:keyword) || '%')
        AND (
          (:filter = 'not_yet' AND (
             (:stage <> '' AND flow_status = :stage)
             OR (:stage = '' AND jsonb_array_length(flow_history) = 0)))
          OR (:filter = 'submitted' AND (
             (:stage <> '' AND flow_status <> :stage
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(flow_history) h
                            WHERE h ->> 'action' = 'submit' AND h ->> 'from' = :stage))
             OR (:stage = '' AND jsonb_array_length(flow_history) > 0
                   AND last_submitted_by IS NOT NULL))))
      SQL
      SampleReceipt.where(conds, tenant_id: tenant_id, contract_id: contract_id,
                                 keyword: keyword.to_s, stage: stage.to_s, filter: filter)
                   .order(updated_at: :desc, commission_code: :asc).map { |e| dto(e) }
    end
  end
end
