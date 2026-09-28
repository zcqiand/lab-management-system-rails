# frozen_string_literal: true

module CalculationMethod
  # M06.F05 计算方法 —— lab-springboot CalculationMethodService +
  # CalculationMethodMapper 1:1 镜像。平台级字典（无 tenant_id，per V012 备注）。
  # 复合主键 (inspection_object_code, inspection_parameter_code)；
  # list 双过滤 + 排序 sort_order, object, parameter。
  class CalculationMethodService
    include UpdateFields

    # 镜像 CalculationMethodMapper.applyUpdate 的字段判定
    UPDATE_FIELDS = {
      'testingStandardCode' => %i[testing_standard_code truthy],
      'reportNameCode' => %i[report_name_code truthy],
      'algorithmType' => %i[algorithm_type truthy],
      'specimenCount' => %i[specimen_count strict],
      'formula' => %i[formula truthy],
      'conditions' => %i[conditions truthy],
      'roundingRule' => %i[rounding_rule truthy],
      'remark' => %i[remark truthy],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(object_code, parameter_code)
      scope = InspectionCalculationMethod.all
      scope = scope.where(inspection_object_code: object_code) if object_code.present?
      scope = scope.where(inspection_parameter_code: parameter_code) if parameter_code.present?
      scope.order(:sort_order, :inspection_object_code, :inspection_parameter_code)
           .map { |e| dto(e) }
    end

    def get(object_code, parameter_code)
      dto(found!(object_code, parameter_code))
    end

    def create(body)
      object_code = body['inspectionObjectCode']
      parameter_code = body['inspectionParameterCode']
      if object_code.nil? || parameter_code.nil?
        raise ArgumentError, 'inspectionObjectCode and inspectionParameterCode are required'
      end

      now = ApplicationRecord.now_iso
      # springboot repo.save = JPA merge（同 PK 覆盖整行）——共库四方对拍下
      # 裸 insert 会 UniqueViolation 500（2026-09-29 live run2/3 实锤）。
      key = { inspection_object_code: object_code, inspection_parameter_code: parameter_code }
      entry = InspectionCalculationMethod.find_by(key) ||
              InspectionCalculationMethod.new(key)
      entry.assign_attributes(create_attrs(body, object_code, parameter_code, now))
      entry.save!
      dto(entry)
    end

    def update(object_code, parameter_code, body)
      entity = found!(object_code, parameter_code)
      apply_update(entity, body)
      entity.save!
      dto(entity)
    end

    def delete(object_code, parameter_code)
      found!(object_code, parameter_code).destroy!
    end

    private

    def found!(object_code, parameter_code)
      rec = InspectionCalculationMethod.find_by(
        inspection_object_code: object_code, inspection_parameter_code: parameter_code
      )
      if rec.nil?
        raise ActiveRecord::RecordNotFound,
              "CalculationMethod not found: #{object_code}/#{parameter_code}"
      end

      rec
    end

    # 镜像 CalculationMethodMapper.fromCreate 的枚举缺省
    # algorithmType=manual / specimenCount=1 / sortOrder=0
    def create_attrs(body, object_code, parameter_code, now)
      {
        inspection_object_code: object_code,
        inspection_parameter_code: parameter_code,
        testing_standard_code: body['testingStandardCode'],
        report_name_code: body['reportNameCode'],
        algorithm_type: body['algorithmType'] || 'manual',
        specimen_count: body['specimenCount'] || 1,
        formula: body['formula'],
        conditions: body['conditions'],
        rounding_rule: body['roundingRule'],
        remark: body['remark'],
        sort_order: body['sortOrder'] || 0,
        created_at: now,
        updated_at: now
      }
    end

    # 镜像 CalculationMethodMapper.applyUpdate：字段级判定跳过，updated_at 恒刷新
    def apply_update(entity, body)
      apply_fields(entity, body, UPDATE_FIELDS)
      entity.updated_at = ApplicationRecord.now_iso
    end

    def dto(e)
      {
        inspection_object_code: e.inspection_object_code,
        inspection_parameter_code: e.inspection_parameter_code,
        testing_standard_code: e.testing_standard_code,
        report_name_code: e.report_name_code,
        algorithm_type: e.algorithm_type,
        specimen_count: e.specimen_count,
        formula: e.formula,
        conditions: e.conditions,
        rounding_rule: e.rounding_rule,
        remark: e.remark,
        sort_order: e.sort_order,
        created_at: e.created_at,
        updated_at: e.updated_at
      }
    end
  end
end
