# frozen_string_literal: true

# M06.F07 报告名称 controller（lab-springboot InspectionReportNameController 镜像）。
# 5 CRUD 端点 + 3 类 junction link/unlink/list（POST/DELETE 恒 204；
# junction list GET 用短信封 page=1/pageSize=total）。
class ReportNamesController < ApplicationController
  include JwtGuard

  def list_report_names
    items = service.list(params[:keyword])
    render_dict_envelope(items)
  end

  def get_report_name
    render_camel(service.get(params[:code]))
  end

  def create_report_name
    render_camel(service.create(request.request_parameters))
  end

  def update_report_name
    render_camel(service.update(params[:code], request.request_parameters))
  end

  def delete_report_name
    service.delete(params[:code])
    head :no_content
  end

  # === junction link/unlink（B6）===

  def link_object_report_name
    junction.link_object_report_name(request.request_parameters)
    head :no_content
  end

  def unlink_object_report_name
    body = request.request_parameters
    junction.unlink_object_report_name(body['inspectionObjectCode'], body['reportNameCode'])
    head :no_content
  end

  def list_object_report_name_links
    items = junction.list_object_report_name_links(
      params[:inspectionObjectCode], params[:reportNameCode]
    )
    render_junction_envelope(items)
  end

  def link_report_name_parameter
    junction.link_report_name_parameter(request.request_parameters)
    head :no_content
  end

  def unlink_report_name_parameter
    body = request.request_parameters
    junction.unlink_report_name_parameter(body['reportNameCode'],
                                          body['inspectionParameterCode'])
    head :no_content
  end

  def list_report_name_parameter_links
    items = junction.list_report_name_parameter_links(
      params[:reportNameCode], params[:inspectionParameterCode]
    )
    render_junction_envelope(items)
  end

  def link_report_name_standard
    junction.link_report_name_standard(request.request_parameters)
    head :no_content
  end

  def unlink_report_name_standard
    body = request.request_parameters
    junction.unlink_report_name_standard(
      body['reportNameCode'], body['inspectionStandardCode'], body['role']
    )
    head :no_content
  end

  def list_report_name_standard_links
    items = junction.list_report_name_standard_links(params[:reportNameCode], params[:role])
    render_junction_envelope(items)
  end

  private

  def service
    @service ||= ReportNames::InspectionReportNameService.new
  end

  def junction
    @junction ||= InspectionDictionary::InspectionJunctionService.new
  end

  # 字典 list 信封：page 缺省 1、pageSize 缺省 = items.size（wrapDict 语义）
  def render_dict_envelope(items)
    page = params.fetch(:page, 1).to_i
    page_size = params.key?(:pageSize) ? params[:pageSize].to_i : items.size
    render_camel({ items: items, page: page, page_size: page_size, total: items.size })
  end

  # junction list 信封：page 恒 1（镜像 springboot 200Response 硬编码）
  def render_junction_envelope(items)
    render_camel({ items: items, page: 1, page_size: items.size, total: items.size })
  end
end
