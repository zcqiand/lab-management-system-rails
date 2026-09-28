# frozen_string_literal: true

module ReportNames
  # M06.F07 报告名称 —— lab-springboot InspectionReportNameService +
  # InspectionReportNameMapper 1:1 镜像。平台级字典（无 tenant_id）。
  # ext_fields 是 List<ExtFieldDef> 走 jsonb；DTO 端 null/blank 回退 []。
  class InspectionReportNameService
    include UpdateFields

    # 镜像 InspectionReportNameMapper.applyUpdate 的字段判定
    UPDATE_FIELDS = {
      'name' => %i[name truthy],
      'fullName' => %i[full_name truthy],
      'templatePath' => %i[template_path truthy],
      'summaryName' => %i[summary_name truthy],
      'extFields' => %i[ext_fields truthy],
      'description' => %i[description truthy],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(keyword)
      scope = InspectionReportName.all
      scope = scope.where(keyword_clause, kw: "%#{keyword.downcase}%") if keyword.present?
      scope.order(:sort_order, :code).map { |e| dto(e) }
    end

    def get(code)
      dto(found!(code))
    end

    def create(body)
      raise ArgumentError, 'code and name are required' if body['code'].nil? || body['name'].nil?

      now = ApplicationRecord.now_iso
      # springboot repo.save = JPA merge（同 PK 覆盖整行，含 created_at）——
      # 共库四方对拍下先建方已占 code，裸 insert 会 UniqueViolation 500
      # （2026-09-29 live run2/3 实锤）。
      entry = InspectionReportName.find_by(code: body['code']) ||
              InspectionReportName.new(code: body['code'])
      entry.assign_attributes(
        name: body['name'],
        full_name: body['fullName'],
        template_path: body['templatePath'],
        summary_name: body['summaryName'],
        ext_fields: body['extFields'],
        description: body['description'],
        sort_order: body['sortOrder'] || 0,
        created_at: now,
        updated_at: now
      )
      entry.save!
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
      rec = InspectionReportName.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "ReportName not found: #{code}" if rec.nil?

      rec
    end

    # 镜像 InspectionReportNameMapper.applyUpdate：字段级判定跳过，updated_at 恒刷新
    def apply_update(entity, body)
      apply_fields(entity, body, UPDATE_FIELDS)
      entity.updated_at = ApplicationRecord.now_iso
    end

    def keyword_clause
      'LOWER(code) LIKE :kw OR LOWER(name) LIKE :kw'
    end

    # 镜像 deserialize：null/blank -> []（响应恒数组）
    def dto(e)
      {
        code: e.code,
        name: e.name,
        full_name: e.full_name,
        template_path: e.template_path,
        summary_name: e.summary_name,
        ext_fields: e.ext_fields.is_a?(Array) ? e.ext_fields : [],
        description: e.description,
        sort_order: e.sort_order,
        created_at: e.created_at,
        updated_at: e.updated_at
      }
    end
  end
end
