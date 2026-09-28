# frozen_string_literal: true

# M06.F05 计算方法 controller（lab-springboot CalculationMethodController 镜像）。
# 5 端点；平台级字典不读 JWT claims（仍挂 JwtGuard）；list 返回裸数组（无分页信封）。
class CalculationMethodsController < ApplicationController
  include JwtGuard

  def list_calculation_methods
    render_camel(service.list(params[:inspectionObjectCode], params[:inspectionParameterCode]))
  end

  def get_calculation_method
    render_camel(service.get(params[:inspection_object_code], params[:inspection_parameter_code]))
  end

  def create_calculation_method
    render_camel(service.create(request.request_parameters))
  end

  def update_calculation_method
    render_camel(
      service.update(
        params[:inspection_object_code],
        params[:inspection_parameter_code],
        request.request_parameters
      )
    )
  end

  def delete_calculation_method
    service.delete(params[:inspection_object_code], params[:inspection_parameter_code])
    head :no_content
  end

  private

  def service
    @service ||= CalculationMethod::CalculationMethodService.new
  end
end
