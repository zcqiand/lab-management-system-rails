# frozen_string_literal: true

module TechnicalRequirement
  # TechnicalRequirementService 的字段装配半体（fromCreate 缺省 + DTO），
  # 拆出以守住 Metrics/ClassLength。镜像 TechnicalRequirementMapper。
  module TechnicalRequirementFields
    # fromCreate 的枚举缺省：valueType=numeric / comparison=≥ /
    # judgmentMode=manual / verificationStatus=draft
    ENUM_DEFAULTS = {
      'valueType' => [:value_type, 'numeric'],
      'comparison' => [:comparison, '≥'],
      'judgmentMode' => [:judgment_mode, 'manual'],
      'verificationStatus' => [:verification_status, 'draft']
    }.freeze

    # 无缺省、直透 body 的可空列
    NULLABLE = %w[conditions minValue maxValue targetValue expression unit clause
                  sourcePage sourceHash brand model grade spec sieve remark].freeze

    private

    def create_attrs(body, tenant_id, now)
      attrs = { tenant_id: tenant_id,
                inspection_object_code: body['inspectionObjectCode'],
                inspection_parameter_code: body['inspectionParameterCode'],
                judgment_standard_code: body['judgmentStandardCode'] }
      attrs.update(enum_attrs(body))
      NULLABLE.each { |json_key| attrs[json_key.underscore.to_sym] = body[json_key] }
      attrs.update(sort_order: body['sortOrder'] || 0, created_at: now, updated_at: now)
    end

    def enum_attrs(body)
      ENUM_DEFAULTS.each_with_object({}) do |(json_key, (column, default)), h|
        h[column] = body[json_key] || default
      end
    end

    def dto(e)
      dto_identity(e).merge(dto_judgment(e))
    end

    def dto_identity(e)
      { tenant_id: e.tenant_id,
        inspection_object_code: e.inspection_object_code,
        inspection_parameter_code: e.inspection_parameter_code,
        judgment_standard_code: e.judgment_standard_code,
        conditions: e.conditions,
        value_type: e.value_type,
        min_value: e.min_value,
        max_value: e.max_value,
        target_value: e.target_value,
        expression: e.expression,
        unit: e.unit,
        comparison: e.comparison }
    end

    def dto_judgment(e)
      { judgment_mode: e.judgment_mode,
        verification_status: e.verification_status,
        clause: e.clause,
        source_page: e.source_page,
        source_hash: e.source_hash,
        brand: e.brand,
        model: e.model,
        grade: e.grade,
        spec: e.spec,
        sieve: e.sieve,
        remark: e.remark,
        sort_order: e.sort_order,
        created_at: e.created_at,
        updated_at: e.updated_at }
    end
  end
end
