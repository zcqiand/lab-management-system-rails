# frozen_string_literal: true

module InspectionDictionary
  # M06 检测能力字典 4 组核心 junction 的 link/unlink/list —— lab-springboot
  # InspectionJunctionService 1:1 镜像（B6/B7）。报告名称 3 组与参数接口 1 组
  # 拆分在同级 ReportNameJunctions / ParamInterfaceJunctions。
  #
  # - link 全部 upsert（同 PK 重复时整行覆盖，含 created_at —— Hibernate merge 语义）
  # - unlink 幂等 204：命中才删，未命中静默 no-op（REQ-2026-001 四方一致）
  # - link 端点关键键 requireNonBlank（null/blank -> IAE 400）；unlink 不校验
  # - list 按 code/role 过滤（blank = 不过滤），DTO 不含时间戳
  class InspectionJunctionService
    include JunctionHelpers
    include ReportNameJunctions
    include ParamInterfaceJunctions

    # === specialty ↔ object ===

    def link_specialty_object(body)
      require_non_blank!(body['inspectionSpecialtyCode'], body['inspectionObjectCode'])
      upsert!(InspectionSpecialtyObject,
              { inspection_specialty_code: body['inspectionSpecialtyCode'],
                inspection_object_code: body['inspectionObjectCode'] },
              { remark: body['remark'] })
    end

    def unlink_specialty_object(body)
      InspectionSpecialtyObject.find_by(
        inspection_specialty_code: body['inspectionSpecialtyCode'],
        inspection_object_code: body['inspectionObjectCode']
      )&.destroy!
    end

    def list_specialty_object_links(specialty_code)
      filter(InspectionSpecialtyObject.all,
             inspection_specialty_code: specialty_code).map do |e|
        { inspection_specialty_code: e.inspection_specialty_code,
          inspection_object_code: e.inspection_object_code, remark: e.remark }
      end
    end

    # === object ↔ parameter ===

    def link_object_parameter(body)
      require_non_blank!(body['inspectionObjectCode'], body['inspectionParameterCode'])
      upsert!(InspectionObjectParameter,
              { inspection_object_code: body['inspectionObjectCode'],
                inspection_parameter_code: body['inspectionParameterCode'] },
              { qualification_level: body['qualificationLevel'] || 'QUALIFIED',
                source_page: body['sourcePage'], remark: body['remark'] })
    end

    def unlink_object_parameter(object_code, parameter_code)
      InspectionObjectParameter.find_by(
        inspection_object_code: object_code, inspection_parameter_code: parameter_code
      )&.destroy!
    end

    def list_object_parameter_links(object_code, parameter_code)
      scope = filter(InspectionObjectParameter.all, inspection_object_code: object_code)
      scope = filter(scope, inspection_parameter_code: parameter_code)
      scope.map do |e|
        { inspection_object_code: e.inspection_object_code,
          inspection_parameter_code: e.inspection_parameter_code,
          qualification_level: e.qualification_level, source_page: e.source_page,
          remark: e.remark }
      end
    end

    # === object ↔ standard (role) ===

    def link_object_standard(body)
      require_non_blank!(body['inspectionObjectCode'], body['inspectionStandardCode'],
                         body['role'])
      upsert!(InspectionObjectStandard,
              { inspection_object_code: body['inspectionObjectCode'],
                inspection_standard_code: body['inspectionStandardCode'],
                role: body['role'] },
              { remark: body['remark'] })
    end

    def unlink_object_standard(object_code, standard_code, role)
      InspectionObjectStandard.find_by(
        inspection_object_code: object_code, inspection_standard_code: standard_code, role: role
      )&.destroy!
    end

    def list_object_standard_links(object_code, role)
      scope = filter(InspectionObjectStandard.all, inspection_object_code: object_code)
      scope = scope.where(role: role) if present?(role)
      scope.map do |e|
        { inspection_object_code: e.inspection_object_code,
          inspection_standard_code: e.inspection_standard_code, role: e.role,
          remark: e.remark }
      end
    end

    # === standard ↔ parameter ===

    def link_standard_parameter(body)
      require_non_blank!(body['inspectionStandardCode'], body['inspectionParameterCode'])
      upsert!(InspectionStandardParameter,
              { inspection_standard_code: body['inspectionStandardCode'],
                inspection_parameter_code: body['inspectionParameterCode'] }, {})
    end

    def unlink_standard_parameter(body)
      InspectionStandardParameter.find_by(
        inspection_standard_code: body['inspectionStandardCode'],
        inspection_parameter_code: body['inspectionParameterCode']
      )&.destroy!
    end

    def list_standard_parameter_links(standard_code, parameter_code)
      scope = filter(InspectionStandardParameter.all, inspection_standard_code: standard_code)
      scope = filter(scope, inspection_parameter_code: parameter_code)
      scope.map do |e|
        { inspection_standard_code: e.inspection_standard_code,
          inspection_parameter_code: e.inspection_parameter_code }
      end
    end
  end
end
