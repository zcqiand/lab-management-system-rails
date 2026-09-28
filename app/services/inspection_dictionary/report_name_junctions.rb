# frozen_string_literal: true

module InspectionDictionary
  # M06.F07 报告名称相关的 3 组 junction —— 自 InspectionJunctionService 拆出
  # （object↔report-name / report-name↔standard(role) / report-name↔parameter）。
  module ReportNameJunctions
    # === object ↔ report-name ===

    def link_object_report_name(body)
      require_non_blank!(body['inspectionObjectCode'], body['reportNameCode'])
      upsert!(InspectionObjectReportName,
              { inspection_object_code: body['inspectionObjectCode'],
                report_name_code: body['reportNameCode'] },
              { remark: body['remark'] })
    end

    def unlink_object_report_name(object_code, report_name_code)
      InspectionObjectReportName.find_by(
        inspection_object_code: object_code, report_name_code: report_name_code
      )&.destroy!
    end

    def list_object_report_name_links(object_code, report_name_code)
      scope = filter(InspectionObjectReportName.all, inspection_object_code: object_code)
      scope = filter(scope, report_name_code: report_name_code)
      scope.map do |e|
        { inspection_object_code: e.inspection_object_code,
          report_name_code: e.report_name_code, remark: e.remark }
      end
    end

    # === report-name ↔ standard (role) ===

    def link_report_name_standard(body)
      require_non_blank!(body['reportNameCode'], body['inspectionStandardCode'], body['role'])
      upsert!(InspectionReportNameStandard,
              { report_name_code: body['reportNameCode'],
                inspection_standard_code: body['inspectionStandardCode'],
                role: body['role'] },
              { remark: body['remark'] })
    end

    def unlink_report_name_standard(report_name_code, standard_code, role)
      InspectionReportNameStandard.find_by(
        report_name_code: report_name_code, inspection_standard_code: standard_code, role: role
      )&.destroy!
    end

    def list_report_name_standard_links(report_name_code, role)
      scope = filter(InspectionReportNameStandard.all, report_name_code: report_name_code)
      scope = scope.where(role: role) if present?(role)
      scope.map do |e|
        { report_name_code: e.report_name_code,
          inspection_standard_code: e.inspection_standard_code, role: e.role,
          remark: e.remark }
      end
    end

    # === report-name ↔ parameter ===

    def link_report_name_parameter(body)
      require_non_blank!(body['reportNameCode'], body['inspectionParameterCode'])
      upsert!(InspectionReportNameParameter,
              { report_name_code: body['reportNameCode'],
                inspection_parameter_code: body['inspectionParameterCode'] },
              { remark: body['remark'] })
    end

    def unlink_report_name_parameter(report_name_code, parameter_code)
      InspectionReportNameParameter.find_by(
        report_name_code: report_name_code, inspection_parameter_code: parameter_code
      )&.destroy!
    end

    def list_report_name_parameter_links(report_name_code, parameter_code)
      scope = filter(InspectionReportNameParameter.all, report_name_code: report_name_code)
      scope = filter(scope, inspection_parameter_code: parameter_code)
      scope.map do |e|
        { report_name_code: e.report_name_code,
          inspection_parameter_code: e.inspection_parameter_code, remark: e.remark }
      end
    end
  end
end
