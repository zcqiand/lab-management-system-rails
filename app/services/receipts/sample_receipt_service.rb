# frozen_string_literal: true

module Receipts
  # M03.F01-F09 接样单域（lab-springboot SampleReceiptService/SampleReceiptMapper 镜像）。
  # tenant-scoped；contract FK 显式校验（NSEE→404）；flow_status 7+1 态机 + flow_history
  # jsonb 追加；list 支持 5.57 三态 filter（not_yet/submitted，jsonb 谓词 native SQL）。
  class SampleReceiptService
    include ReceiptFields
    include ReceiptQueries

    LIST_FIELDS = %w[
      commissionCode commissionDate commissionRegisterCode commissionRegisterDate
      categoryCode projectName clientUnit buildingUnit supervisorUnit constructionUnit
      witnessUnit samplingLocation witness witnessPhone inspector inspectorPhone
      receivedBy sampleSource testCategory testEnvironment mainEquipment testOperator
      testStartDate testEndDate originalRecordNo remark
    ].freeze
    JSON_LIST_FIELDS = %w[judgmentBasis testingBasis testParameters].freeze
    CREATE_FIELDS = %w[contractId] + LIST_FIELDS

    FLOW_STATUSES = %w[
      receiving task_assignment data_entry review approval issuance archived completed
    ].freeze

    def initialize(tenant_id)
      @tenant_id = tenant_id
    end

    def list(contract_id: nil, flow_status: nil, keyword: nil, filter: nil)
      if %w[not_yet submitted].include?(filter)
        return filter_three_state(@tenant_id, contract_id, flow_status, keyword, filter)
      end

      scope = SampleReceipt.where(tenant_id: @tenant_id)
      scope = scope.where(contract_id: contract_id) if contract_id.present?
      scope = scope.where(flow_status: flow_status) if flow_status
      scope = filter_keyword(scope, keyword)
      scope.order(updated_at: :desc, commission_code: :asc).map { |e| dto(e) }
    end

    def get(id)
      dto(find!(id))
    end

    def history(id)
      find!(id).flow_history || []
    end

    def create(req)
      contract_id = req['contractId']
      unless Contract.exists?(tenant_id: @tenant_id, id: contract_id)
        raise ActiveRecord::RecordNotFound, "Contract not found: #{contract_id}"
      end

      now = now_iso
      receipt = SampleReceipt.create!(field_attrs(req, CREATE_FIELDS).merge(
                                        id: new_id, tenant_id: @tenant_id,
                                        flow_status: 'receiving', flow_history: [],
                                        result: '', created_at: now, updated_at: now
                                      ))
      dto(receipt)
    end

    def update(id, req)
      receipt = find!(id)
      field_attrs(req, LIST_FIELDS).compact.each { |col, v| receipt[col] = v }
      JSON_LIST_FIELDS.each do |f|
        v = req[f]
        receipt[f.underscore] = Array(v || []) unless v.nil?
      end
      receipt.updated_at = now_iso
      receipt.save!
      dto(receipt)
    end

    def delete(id)
      find!(id).destroy!
    end

    # M03.F02 任务分配：字段按需更新；仅 receiving 阶段推进 task_assignment 并写 history
    # （action 字面量 "submit" 是真 submit 转移，operator 记 assigneeName —— 参照实现）
    def assign_task(id, req)
      receipt = find!(id)
      %w[assigneeId assigneeName plannedTestDate].each do |f|
        v = req[f]
        receipt[f.underscore] = v unless v.nil?
      end
      if receipt.flow_status == 'receiving'
        receipt.flow_status = 'task_assignment'
        append_history(receipt, action: 'submit', operator: req['assigneeName'],
                                from: 'receiving', to: 'task_assignment',
                                reason: 'M03.F02 任务分配')
      end
      receipt.updated_at = now_iso
      receipt.save!
      dto(receipt)
    end

    # M03.F06 等阶段推进：状态迁移 + last_submitted_by 语义（5.69：submit 写操作人 /
    # withdraw 清空 / return 保留）+ history 记 action 真值（5.75）
    def transition_to(id, **move)
      receipt = find!(id)
      if receipt.flow_status != move[:from]
        raise ArgumentError,
              "Receipt #{id} not in expected stage #{move[:from]} but #{receipt.flow_status}"
      end

      receipt.flow_status = move[:to]
      receipt.last_submitted_by = move[:operator] if move[:action] == 'submit'
      receipt.last_submitted_by = nil if move[:action] == 'withdraw'
      append_history(receipt, **move)
      receipt.updated_at = now_iso
      receipt.save!
      dto(receipt)
    end

    # flow_history 追加（entry 键集 action/from/to/operator/reason + at，jsonb 回读
    # 是 string 键，落库前统一转 string）
    def append_history(receipt, **entry)
      record = entry.transform_keys(&:to_s).merge('at' => now_iso)
      receipt.flow_history = Array(receipt.flow_history) + [record]
    end

    private

    def find!(id)
      SampleReceipt.find_by(tenant_id: @tenant_id, id: id) or
        raise ActiveRecord::RecordNotFound, "Receipt not found: #{id}"
    end
  end
end
