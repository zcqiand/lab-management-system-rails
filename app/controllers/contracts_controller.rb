# frozen_string_literal: true

# M02.F01 合同（B3，5 端点）。tenant-scoped（lab-springboot ContractController 镜像）。
class ContractsController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  # @impl M02.F01.I01 (book anchor xr-know-012)
  def list_contracts
    render_business_envelope(service.list(keyword: query_param(:keyword),
                                          status: enum_param!(query_param(:status),
                                                              Contracts::ContractService::STATUSES)))
  end

  # @impl M02.F01.I02 (book anchor xr-know-012)
  def get_contract
    render_camel(service.get(params[:id]))
  end

  # @impl M02.F01.I03 (book anchor xr-know-012)
  def create_contract
    render_camel(service.create(body_params))
  end

  # @impl M02.F01.I04 (book anchor xr-know-012)
  def update_contract
    render_camel(service.update(params[:id], body_params))
  end

  # @impl M02.F01.I05 (book anchor xr-know-012)
  def delete_contract
    service.delete(params[:id])
    head :no_content
  end

  private

  def service
    @service ||= Contracts::ContractService.new(current_tenant_id)
  end
end
