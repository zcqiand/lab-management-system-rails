# frozen_string_literal: true

# M02.F01 合同（B3，5 端点）。tenant-scoped（lab-springboot ContractController 镜像）。
class ContractsController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  def list_contracts
    render_business_envelope(service.list(keyword: query_param(:keyword),
                                          status: enum_param!(query_param(:status),
                                                              Contracts::ContractService::STATUSES)))
  end

  def get_contract
    render_camel(service.get(params[:id]))
  end

  def create_contract
    render_camel(service.create(body_params))
  end

  def update_contract
    render_camel(service.update(params[:id], body_params))
  end

  def delete_contract
    service.delete(params[:id])
    head :no_content
  end

  private

  def service
    @service ||= Contracts::ContractService.new(current_tenant_id)
  end
end
