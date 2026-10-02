# frozen_string_literal: true

# M05 报告汇总 + 仪表盘（B4，2 端点）。tenant 从 JWT claim 取
# （lab-springboot SummaryController 镜像）。
class SummaryController < ApplicationController
  include JwtGuard
  include BusinessEnvelope # 只用 query_param（summary 无分页信封）

  # @impl M05.F01.I01 (book anchor xr-know-012)
  def get_report_summary
    render_camel(service.report_summary(query_param(:categoryCode),
                                        query_param(:dateFrom), query_param(:dateTo)))
  end

  # stats 键集是 wire 形状（funnelByStage 的 "pending_collect" 是 openapi 生成名，
  # 不得被 camelCase 变换折叠成 pendingCollect）—— 直接 render，不走 render_camel。
  # @impl M05.F01.I06 (book anchor xr-know-012)
  def get_dashboard_stats
    render json: service.dashboard_stats
  end

  private

  def service
    @service ||= Summary::SummaryService.new(current_tenant_id)
  end
end
