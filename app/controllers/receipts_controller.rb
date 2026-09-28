# frozen_string_literal: true

# M03.F01/F02/F05-F09 接样单（B3）：CRUD + history + 任务分配 + 7 阶段全 act 模式
# （lab-springboot SampleReceiptController 镜像，2026-09-17 收敛版 7 act op）。
class ReceiptsController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  def list_receipts
    render_business_envelope(receipt_service.list(
                               contract_id: query_param(:contractId),
                               flow_status: enum_param!(query_param(:flowStatus),
                                                        Receipts::SampleReceiptService::FLOW_STATUSES),
                               keyword: query_param(:keyword),
                               filter: query_param(:filter)
                             ))
  end

  def get_receipt
    render_camel(receipt_service.get(params[:id]))
  end

  def create_receipt
    render_camel(receipt_service.create(body_params))
  end

  def update_receipt
    render_camel(receipt_service.update(params[:id], body_params))
  end

  def delete_receipt
    receipt_service.delete(params[:id])
    head :no_content
  end

  # M03.F01.I06 流程历史（jsonb → List<FlowHistoryEntry>）
  def get_receipt_history
    render_camel(receipt_service.history(params[:id]))
  end

  # M03.F02 任务分配
  def assign_task
    render_camel(receipt_service.assign_task(params[:id], body_params))
  end

  # ── 7 个 act 端点：共享 body {ids[], action, operator, reason?}，stage 由路径定 ──
  def act_flow_receiving
    act_flow('receiving')
  end

  def act_flow_assigning
    act_flow('task_assignment')
  end

  def act_flow_data_entry
    act_flow('data_entry')
  end

  def act_flow_review
    act_flow('review')
  end

  def act_flow_approve
    act_flow('approval')
  end

  def act_flow_issuance
    act_flow('issuance')
  end

  def act_flow_archived
    act_flow('archived')
  end

  private

  def act_flow(stage)
    flow_service = Receipts::ReportFlowService.new(receipt_service)
    render_camel(flow_service.act(stage, body_params))
  end

  def receipt_service
    @receipt_service ||= Receipts::SampleReceiptService.new(current_tenant_id)
  end
end
