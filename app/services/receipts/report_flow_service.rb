# frozen_string_literal: true

module Receipts
  # 报告流程状态机 M03.F01-F08，7 阶段全 act 模式（lab-springboot ReportFlowService 镜像，
  # 2026-09-17 收敛版：POST /receipts/<stage>/act，body.action={submit|return|withdraw}）。
  #
  # action 范围因 stage 而异：
  # - receiving/assigning/data-entry：{submit, return, withdraw}
  # - review/approve/issuance：{submit, return}
  # - archived：仅 submit（终态自转移，写 history 当 audit，语义按 submit 走 5.69）
  # WITHDRAW 仅在 receiving 阶段自转移。per-id try/catch：单条失败出 err 结果不整批 5xx。
  class ReportFlowService
    SUBMIT_NEXT = {
      'receiving' => 'task_assignment', 'task_assignment' => 'data_entry',
      'data_entry' => 'review', 'review' => 'approval', 'approval' => 'issuance',
      'issuance' => 'archived'
    }.freeze
    RETURN_PREV = {
      'task_assignment' => 'receiving', 'data_entry' => 'task_assignment',
      'review' => 'data_entry', 'approval' => 'review', 'issuance' => 'approval',
      'archived' => 'issuance'
    }.freeze

    def initialize(receipt_service)
      @receipts = receipt_service
    end

    def act(stage, body)
      require_operator!(body)
      operator = body['operator']
      reason = body['reason']
      Array(body['ids']).map do |id|
        if stage == 'archived'
          act_archived_one(id, body['action'], operator, reason)
        else
          act_stage_one(stage, id, body['action'], operator, reason)
        end
      end
    end

    private

    # 5.75 operator 契约必填（SSOT = lab-nextjs act-route.ts:39-44）：缺失与空串都 400，
    # 校验先于 per-id 循环（整批拒）。
    def require_operator!(body)
      operator = body['operator']
      return unless operator.nil? || operator.empty?

      raise ArgumentError, 'operator is required'
    end

    def act_stage_one(stage, id, action, operator, reason)
      current = @receipts.get(id)[:flow_status]
      return err(id, "Stage mismatch: requires #{stage} but is #{current}") if current != stage

      target = target_of(current, action)
      return err(id, "Invalid transition from #{current} with #{action}") if target.nil?

      @receipts.transition_to(id, from: current, to: target, action: action,
                                  operator: operator, reason: reason)
      ok(id, target)
    rescue StandardError => e
      err(id, e.message)
    end

    # archived 终态：仅 submit；自转移写 audit（reason 缺省 "archived: post-archive audit"，
    # 语义按 submit —— lastSubmittedBy 写操作人）
    def act_archived_one(id, action, operator, reason)
      current = @receipts.get(id)[:flow_status]
      return archived_stage_err(id, current) if current != 'archived'
      return submit_only_err(id, action) unless action == 'submit'

      @receipts.transition_to(id, from: 'archived', to: 'archived', action: 'submit',
                                  operator: operator,
                                  reason: reason || 'archived: post-archive audit')
      ok(id, 'archived')
    rescue StandardError => e
      err(id, e.message)
    end

    def archived_stage_err(id, current)
      err(id, "Stage mismatch: requires archived but is #{current}")
    end

    def submit_only_err(id, action)
      err(id, "Action not allowed: archived accepts only submit but got #{action}")
    end

    def target_of(current, action)
      case action
      when 'submit' then SUBMIT_NEXT[current]
      when 'return' then RETURN_PREV[current]
      when 'withdraw' then current == 'receiving' ? 'receiving' : nil
      end
    end

    def ok(id, flow_status)
      { id: id, ok: true, flowStatus: flow_status }
    end

    def err(id, message)
      { id: id, ok: false, message: message }
    end
  end
end
