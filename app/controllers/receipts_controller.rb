# frozen_string_literal: true

# M03.F01/F02/F05-F09 接样单（B3）：CRUD + history + 任务分配 + 7 阶段全 act 模式
# （lab-springboot SampleReceiptController 镜像，2026-09-17 收敛版 7 act op）。
class ReceiptsController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  # @impl M03.F01.I01 (book anchor xr-know-012)
  def list_receipts
    render_business_envelope(receipt_service.list(
                               contract_id: query_param(:contractId),
                               flow_status: enum_param!(query_param(:flowStatus),
                                                        Receipts::SampleReceiptService::FLOW_STATUSES),
                               keyword: query_param(:keyword),
                               filter: query_param(:filter)
                             ))
  end

  # @impl M03.F01.I02 (book anchor xr-know-012)
  # @impl M03.F05.I02 (book anchor xr-know-012)
  # @impl M03.F06.I02 (book anchor xr-know-012)
  # @impl M03.F07.I02 (book anchor xr-know-012)
  # @impl M03.F08.I02 (book anchor xr-know-012)
  # @impl M03.F09.I01 (book anchor xr-know-012)
  def get_receipt
    render_camel(receipt_service.get(params[:id]))
  end

  # @impl M03.F01.I03 (book anchor xr-know-012)
  def create_receipt
    render_camel(receipt_service.create(body_params))
  end

  # @impl M03.F01.I04 (book anchor xr-know-012)
  def update_receipt
    render_camel(receipt_service.update(params[:id], body_params))
  end

  # @impl M03.F01.I05 (book anchor xr-know-012)
  def delete_receipt
    receipt_service.delete(params[:id])
    head :no_content
  end

  # M03.F01.I06 流程历史（jsonb → List<FlowHistoryEntry>）
  # @impl M03.F01.I06 (book anchor xr-know-012)
  def get_receipt_history
    render_camel(receipt_service.history(params[:id]))
  end

  # M03.F02 任务分配
  # @impl M03.F02.I01 (book anchor xr-know-012)
  def assign_task
    render_camel(receipt_service.assign_task(params[:id], body_params))
  end

  # ── 7 个 act 端点：共享 body {ids[], action, operator, reason?}，stage 由路径定 ──
  # @impl M03.F01.I08 (book anchor xr-know-012)
  def act_flow_receiving
    act_flow('receiving')
  end

  # @impl M03.F02.I05 (book anchor xr-know-012)
  def act_flow_assigning
    act_flow('task_assignment')
  end

  # @impl M03.F03.I12 (book anchor xr-know-012)
  def act_flow_data_entry
    act_flow('data_entry')
  end

  # @impl M03.F05.I07 (book anchor xr-know-012)
  def act_flow_review
    act_flow('review')
  end

  # @impl M03.F06.I05 (book anchor xr-know-012)
  def act_flow_approve
    act_flow('approval')
  end

  # @impl M03.F07.I05 (book anchor xr-know-012)
  def act_flow_issuance
    act_flow('issuance')
  end

  # @impl M03.F08.I05 (book anchor xr-know-012)
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
