# frozen_string_literal: true

module Catalog
  # M04.F06/07/08/09 码表服务 —— lab-springboot CatalogService +
  # InspectionCatalogMapper 1:1 镜像。4 表结构一致（brand/model/spec/grade）：
  # tenant 隔离（unique (tenant_id, code)，code 是全局 PK 列但按 tenant 过滤后寻址），
  # list 按 inspectionObjectCode + keyword（code/name 大小写不敏感 LIKE）过滤，
  # 排序 sort_order, code；DTO 蛇形 hash，camelCase 由渲染层处理。
  class CatalogService
    KINDS = {
      brand: { model: InspectionBrand, label: 'Brand' },
      model: { model: InspectionModel, label: 'Model' },
      spec: { model: InspectionSpec, label: 'Spec' },
      grade: { model: InspectionGrade, label: 'Grade' }
    }.freeze

    def list(kind, tenant_id, object_code, keyword)
      scope = meta(kind)[:model].where(tenant_id: tenant_id)
      scope = scope.where(inspection_object_code: object_code) if object_code.present?
      scope = scope.where(keyword_clause, kw: "%#{keyword.downcase}%") if keyword.present?
      scope.order(sort_order: :asc, code: :asc).map { |e| entry_dto(e) }
    end

    def create(kind, tenant_id, body)
      raise ArgumentError, 'code and name are required' if body['code'].nil? || body['name'].nil?

      now = ApplicationRecord.now_iso
      entry = meta(kind)[:model].create!(entry_attrs(kind, tenant_id, body, now))
      entry_dto(entry)
    end

    def update(kind, tenant_id, code, body)
      entity = find!(kind, tenant_id, code)
      apply_update(entity, body)
      entity.save!
      entry_dto(entity)
    end

    def delete(kind, tenant_id, code)
      find!(kind, tenant_id, code).destroy!
    end

    private

    def meta(kind)
      KINDS.fetch(kind.to_sym)
    end

    def find!(kind, tenant_id, code)
      rec = meta(kind)[:model].find_by(tenant_id: tenant_id, code: code)
      raise ActiveRecord::RecordNotFound, "#{meta(kind)[:label]} not found: #{code}" if rec.nil?

      rec
    end

    def entry_attrs(_kind, tenant_id, body, now)
      {
        tenant_id: tenant_id,
        code: body['code'],
        inspection_object_code: body['inspectionObjectCode'],
        name: body['name'],
        remark: body['remark'],
        sort_order: body['sortOrder'] || 0,
        created_at: now,
        updated_at: now
      }
    end

    # 镜像 applyUpdate：nil 字段跳过（部分更新），updated_at 恒刷新
    def apply_update(entity, body)
      entity.inspection_object_code = body['inspectionObjectCode'] if body['inspectionObjectCode']
      entity.name = body['name'] if body['name']
      entity.remark = body['remark'] if body['remark']
      entity.sort_order = body['sortOrder'] if body['sortOrder']
      entity.updated_at = ApplicationRecord.now_iso
    end

    def keyword_clause
      'LOWER(code) LIKE :kw OR LOWER(name) LIKE :kw'
    end

    def entry_dto(e)
      {
        code: e.code,
        tenant_id: e.tenant_id,
        inspection_object_code: e.inspection_object_code,
        name: e.name,
        remark: e.remark,
        sort_order: e.sort_order,
        created_at: e.created_at,
        updated_at: e.updated_at
      }
    end
  end
end
