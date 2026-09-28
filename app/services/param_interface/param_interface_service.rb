# frozen_string_literal: true

module ParamInterface
  # M10 参数接口 —— lab-springboot ParamInterfaceService + ParamInterfaceMapper
  # 1:1 镜像。平台级字典（无 tenant_id）。config 是 Map 走 jsonb；DTO 端 null/blank
  # 回退 {}。create 必填 code + componentPath（ct 实证：宽松 mock 曾掩盖）。
  class ParamInterfaceService
    def list(keyword)
      scope = InspectionParamInterface.all
      scope = scope.where(keyword_clause, kw: "%#{keyword.downcase}%") if keyword.present?
      scope.order(:sort_order, :code).map { |e| dto(e) }
    end

    def get(code)
      dto(found!(code))
    end

    def create(body)
      raise ArgumentError, 'code and componentPath are required' if body['code'].nil? ||
                                                                    body['componentPath'].nil?

      now = ApplicationRecord.now_iso
      entry = InspectionParamInterface.create!(
        code: body['code'],
        name: body['name'],
        component_path: body['componentPath'],
        description: body['description'],
        is_official: body['isOfficial'],
        sort_order: body['sortOrder'] || 0,
        config: body['config'],
        created_at: now,
        updated_at: now
      )
      dto(entry)
    end

    def update(code, body)
      entity = found!(code)
      apply_update(entity, body)
      entity.save!
      dto(entity)
    end

    def delete(code)
      found!(code).destroy!
    end

    private

    def found!(code)
      rec = InspectionParamInterface.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "ParamInterface not found: #{code}" if rec.nil?

      rec
    end

    # 镜像 ParamInterfaceMapper.applyUpdate：nil 字段跳过，updated_at 恒刷新
    def apply_update(entity, body)
      entity.name = body['name'] if body['name']
      entity.component_path = body['componentPath'] if body['componentPath']
      entity.description = body['description'] if body['description']
      entity.is_official = body['isOfficial'] unless body['isOfficial'].nil?
      entity.sort_order = body['sortOrder'] if body['sortOrder']
      entity.config = body['config'] if body['config']
      entity.updated_at = ApplicationRecord.now_iso
    end

    def keyword_clause
      'LOWER(code) LIKE :kw OR LOWER(name) LIKE :kw'
    end

    # 镜像 deserialize：null/blank -> {}（响应恒对象）
    def dto(e)
      {
        code: e.code,
        name: e.name,
        component_path: e.component_path,
        description: e.description,
        is_official: e.is_official,
        sort_order: e.sort_order,
        config: e.config.is_a?(Hash) ? e.config : {},
        created_at: e.created_at,
        updated_at: e.updated_at
      }
    end
  end
end
