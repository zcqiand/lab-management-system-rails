# frozen_string_literal: true

# M04.F06-F09 码表 controller（lab-springboot InspectionCatalogController 镜像）。
# 16 端点 4 字典同构；list 全量 List 不切页，包 Page 信封（page 缺省 1、
# pageSize 缺省 = items.size —— 2026-09-16 T11 live 语义，照抄 controller 实测）。
class CatalogController < ApplicationController
  include JwtGuard

  KINDS = %i[brand model spec grade].freeze

  # === Brand (M04.F09) ===
  def list_brands
    render_dict_list(:brand)
  end

  def create_brand
    render_create(:brand)
  end

  def update_brand
    render_update(:brand)
  end

  def delete_brand
    render_delete(:brand)
  end

  # === Model (M04.F06) ===
  def list_models
    render_dict_list(:model)
  end

  def create_model
    render_create(:model)
  end

  def update_model
    render_update(:model)
  end

  def delete_model
    render_delete(:model)
  end

  # === Spec (M04.F07) ===
  def list_specs
    render_dict_list(:spec)
  end

  def create_spec
    render_create(:spec)
  end

  def update_spec
    render_update(:spec)
  end

  def delete_spec
    render_delete(:spec)
  end

  # === Grade (M04.F08) ===
  def list_grades
    render_dict_list(:grade)
  end

  def create_grade
    render_create(:grade)
  end

  def update_grade
    render_update(:grade)
  end

  def delete_grade
    render_delete(:grade)
  end

  private

  def service
    @service ||= Catalog::CatalogService.new
  end

  # 全量 items + 信封（page/pageSize 只回显不切页，镜像 springboot effectivePage/effectivePageSize）
  def render_dict_list(kind)
    items = service.list(kind, current_tenant_id, params[:inspectionObjectCode], params[:keyword])
    page = params.fetch(:page, 1).to_i
    page_size = params.key?(:pageSize) ? params[:pageSize].to_i : items.size
    render_camel({ items: items, page: page, page_size: page_size, total: items.size })
  end

  def render_create(kind)
    render_camel(service.create(kind, current_tenant_id, request.request_parameters))
  end

  def render_update(kind)
    render_camel(
      service.update(kind, current_tenant_id, params[:code], request.request_parameters)
    )
  end

  def render_delete(kind)
    service.delete(kind, current_tenant_id, params[:code])
    head :no_content
  end
end
