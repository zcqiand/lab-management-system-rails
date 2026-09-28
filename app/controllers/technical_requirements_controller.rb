# frozen_string_literal: true

# M06.F06 技术要求 controller（lab-springboot TechnicalRequirementController 镜像）。
# 5 端点；tenant 从 JWT claim 取（JwtGuard#current_tenant_id）；list 返回裸数组。
class TechnicalRequirementsController < ApplicationController
  include JwtGuard

  def list_technical_requirements
    render_camel(
      service.list(
        current_tenant_id,
        params[:inspectionObjectCode],
        params[:inspectionParameterCode],
        params[:judgmentStandardCode],
        params[:verificationStatus]
      )
    )
  end

  def get_technical_requirement
    render_camel(service.get(tenant, object_code, parameter_code, standard_code))
  end

  def create_technical_requirement
    render_camel(service.create(request.request_parameters, current_tenant_id))
  end

  def update_technical_requirement
    render_camel(service.update(tenant, object_code, parameter_code, standard_code, body))
  end

  def delete_technical_requirement
    service.delete(tenant, object_code, parameter_code, standard_code)
    head :no_content
  end

  private

  def service
    @service ||= TechnicalRequirement::TechnicalRequirementService.new
  end

  def tenant
    current_tenant_id
  end

  def object_code
    params[:inspection_object_code]
  end

  def parameter_code
    params[:inspection_parameter_code]
  end

  def standard_code
    params[:judgment_standard_code]
  end

  def body
    request.request_parameters
  end
end
