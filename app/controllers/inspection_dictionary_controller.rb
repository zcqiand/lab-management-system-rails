# frozen_string_literal: true

# M06 检测能力字典 controller（lab-springboot InspectionDictionaryController 镜像）。
# 四实体 CRUD（wrapDict 信封：page 缺省 1、pageSize 缺省 = items.size）；
# 四类 junction link/unlink/list 拆分在 InspectionDictionaryLinks。
class InspectionDictionaryController < ApplicationController
  include JwtGuard
  include InspectionDictionaryLinks

  # === specialties ===

  # @impl M06.F01.I01 (book anchor xr-know-012)
  def list_specialties
    render_dict_envelope(service.list_specialties(params[:keyword]))
  end

  # @impl M06.F01.I02 (book anchor xr-know-012)
  def create_specialty
    render_camel(service.create_specialty(request.request_parameters))
  end

  # @impl M06.F01.I03 (book anchor xr-know-012)
  def update_specialty
    render_camel(service.update_specialty(params[:code], request.request_parameters))
  end

  # @impl M06.F01.I04 (book anchor xr-know-012)
  def delete_specialty
    service.delete_specialty(params[:code])
    head :no_content
  end

  # === objects ===

  # @impl M06.F02.I01 (book anchor xr-know-012)
  def list_objects
    render_dict_envelope(service.list_objects(params[:keyword],
                                              params[:inspectionSpecialtyCode]))
  end

  # @impl M06.F02.I02 (book anchor xr-know-012)
  def create_object
    render_camel(service.create_object(request.request_parameters))
  end

  # @impl M06.F02.I03 (book anchor xr-know-012)
  def update_object
    render_camel(service.update_object(params[:code], request.request_parameters))
  end

  # @impl M06.F02.I04 (book anchor xr-know-012)
  def delete_object
    service.delete_object(params[:code])
    head :no_content
  end

  # === parameters ===

  # @impl M06.F03.I01 (book anchor xr-know-012)
  def list_parameters
    render_dict_envelope(service.list_parameters(params[:keyword], params[:sourceType]))
  end

  # @impl M06.F03.I02 (book anchor xr-know-012)
  def create_parameter
    render_camel(service.create_parameter(request.request_parameters))
  end

  # @impl M06.F03.I03 (book anchor xr-know-012)
  def update_parameter
    render_camel(service.update_parameter(params[:code], request.request_parameters))
  end

  # @impl M06.F03.I04 (book anchor xr-know-012)
  def delete_parameter
    service.delete_parameter(params[:code])
    head :no_content
  end

  # === standards ===

  def list_standards
    render_dict_envelope(service.list_standards(params[:keyword], params[:status]))
  end

  def create_standard
    render_camel(service.create_standard(request.request_parameters))
  end

  def update_standard
    render_camel(service.update_standard(params[:code], request.request_parameters))
  end

  def delete_standard
    service.delete_standard(params[:code])
    head :no_content
  end

  private

  def service
    @service ||= InspectionDictionary::InspectionDictionaryService.new
  end

  # 字典 list 信封：page 缺省 1、pageSize 缺省 = items.size（wrapDict 语义）
  def render_dict_envelope(items)
    page = params.fetch(:page, 1).to_i
    page_size = params.key?(:pageSize) ? params[:pageSize].to_i : items.size
    render_camel({ items: items, page: page, page_size: page_size, total: items.size })
  end
end
