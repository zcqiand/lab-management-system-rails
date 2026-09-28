# frozen_string_literal: true

module TechnicalRequirement
  # M06.F06 技术要求 —— lab-springboot TechnicalRequirementService +
  # TechnicalRequirementMapper 1:1 镜像。PK 是业务三键
  # (object, parameter, judgmentStandard)；tenant-scoped（V012）。
  # list 4 过滤（object/parameter/standard/status）+ tenant 收口，排序
  # sort_order, object, parameter, standard。字段装配见 TechnicalRequirementFields。
  class TechnicalRequirementService
    include TechnicalRequirementFields

    def list(tenant_id, object_code, parameter_code, standard_code, status)
      scope = InspectionTechnicalRequirement.where(tenant_id: tenant_id)
      scope = scope.where(inspection_object_code: object_code) if object_code.present?
      scope = scope.where(inspection_parameter_code: parameter_code) if parameter_code.present?
      scope = scope.where(judgment_standard_code: standard_code) if standard_code.present?
      scope = scope.where(verification_status: status) if status.present?
      scope.order(:sort_order, :inspection_object_code, :inspection_parameter_code,
                  :judgment_standard_code).map { |e| dto(e) }
    end

    def get(tenant_id, object_code, parameter_code, standard_code)
      dto(found!(tenant_id, object_code, parameter_code, standard_code))
    end

    def create(body, tenant_id)
      require_keys!(body)
      now = ApplicationRecord.now_iso
      # springboot repo.save = JPA merge（同 PK 覆盖整行）——共库四方对拍下
      # 裸 insert 会 UniqueViolation 500（2026-09-29 live run2/3 实锤）。
      key = { tenant_id: tenant_id,
              inspection_object_code: body['inspectionObjectCode'],
              inspection_parameter_code: body['inspectionParameterCode'],
              judgment_standard_code: body['judgmentStandardCode'] }
      entry = InspectionTechnicalRequirement.find_by(key) ||
              InspectionTechnicalRequirement.new(key)
      entry.assign_attributes(create_attrs(body, tenant_id, now))
      entry.save!
      dto(entry)
    end

    def update(tenant_id, object_code, parameter_code, standard_code, body)
      entity = found!(tenant_id, object_code, parameter_code, standard_code)
      apply_update(entity, body)
      entity.save!
      dto(entity)
    end

    def delete(tenant_id, object_code, parameter_code, standard_code)
      found!(tenant_id, object_code, parameter_code, standard_code).destroy!
    end

    private

    # 三业务键任一缺失 -> IAE（镜像 service 的 requireNonNull 组）
    def require_keys!(body)
      missing = %w[inspectionObjectCode inspectionParameterCode judgmentStandardCode]
                .any? { |k| body[k].nil? }
      return unless missing

      raise ArgumentError,
            'inspectionObjectCode/inspectionParameterCode/judgmentStandardCode are required'
    end

    def found!(tenant_id, object_code, parameter_code, standard_code)
      rec = InspectionTechnicalRequirement.find_by(
        tenant_id: tenant_id,
        inspection_object_code: object_code,
        inspection_parameter_code: parameter_code,
        judgment_standard_code: standard_code
      )
      if rec.nil?
        raise ActiveRecord::RecordNotFound,
              "TechnicalRequirement not found: #{object_code}/#{parameter_code}/#{standard_code}"
      end

      rec
    end

    # 镜像 TechnicalRequirementMapper.applyUpdate：nil 字段跳过，updated_at 恒刷新
    def apply_update(entity, body)
      %w[conditions valueType minValue maxValue targetValue expression unit comparison
         judgmentMode verificationStatus clause sourcePage sourceHash brand model grade
         spec sieve remark sortOrder].each do |json_key|
        entity.public_send("#{json_key.underscore}=", body[json_key]) unless body[json_key].nil?
      end
      entity.updated_at = ApplicationRecord.now_iso
    end
  end
end
