# frozen_string_literal: true

# M10 参数接口 controller（lab-springboot ParamInterfaceController 镜像）。
# 5 CRUD 端点 + junction link/unlink（恒 204）+ links list（短信封 page=1）。
class ParamInterfacesController < ApplicationController
  include JwtGuard

  def list_param_interfaces
    items = service.list(params[:keyword])
    page = params.fetch(:page, 1).to_i
    page_size = params.key?(:pageSize) ? params[:pageSize].to_i : items.size
    render_camel({ items: items, page: page, page_size: page_size, total: items.size })
  end

  # 路由表是 manifest 1:1 镜像（禁改序）：GET/DELETE /param-interfaces/links 被
  # 先声明的 `/:code` 抢匹配 —— 静态段 /links 在 controller 侧转发到 links action
  # （镜像 springboot 字面路径优先于 @PathVariable 模板的语义）。
  def get_param_interface
    return list_param_interface_links if params[:code] == 'links'

    render_camel(service.get(params[:code]))
  end

  def create_param_interface
    render_camel(service.create(request.request_parameters))
  end

  def update_param_interface
    render_camel(service.update(params[:code], request.request_parameters))
  end

  def delete_param_interface
    return unlink_param_interface if params[:code] == 'links'

    service.delete(params[:code])
    head :no_content
  end

  def link_param_interface
    junction.link_param_interface(request.request_parameters)
    head :no_content
  end

  def unlink_param_interface
    body = request.request_parameters
    junction.unlink_param_interface(body['inspectionParameterCode'],
                                    body['paramInterfaceCode'])
    head :no_content
  end

  def list_param_interface_links
    items = junction.list_param_interface_links(params[:inspectionParameterCode],
                                                params[:paramInterfaceCode])
    render_camel({ items: items, page: 1, page_size: items.size, total: items.size })
  end

  private

  def service
    @service ||= ParamInterface::ParamInterfaceService.new
  end

  def junction
    @junction ||= InspectionDictionary::InspectionJunctionService.new
  end
end
