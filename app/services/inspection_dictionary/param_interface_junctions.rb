# frozen_string_literal: true

module InspectionDictionary
  # M10 parameter ↔ param-interface junction（config jsonb）——
  # 自 InspectionJunctionService 拆出。
  module ParamInterfaceJunctions
    # @impl M06.F08.I06 (book anchor xr-know-012)
    def link_param_interface(body)
      require_non_blank!(body['inspectionParameterCode'], body['paramInterfaceCode'])
      upsert!(InspectionParamInterfaceLink,
              { inspection_parameter_code: body['inspectionParameterCode'],
                param_interface_code: body['paramInterfaceCode'] },
              { report_name_code: body['reportNameCode'], config: body['config'] })
    end

    def unlink_param_interface(parameter_code, interface_code)
      InspectionParamInterfaceLink.find_by(
        inspection_parameter_code: parameter_code, param_interface_code: interface_code
      )&.destroy!
    end

    def list_param_interface_links(parameter_code, interface_code)
      scope = filter(InspectionParamInterfaceLink.all, inspection_parameter_code: parameter_code)
      scope = filter(scope, param_interface_code: interface_code)
      scope.map do |e|
        { inspection_parameter_code: e.inspection_parameter_code,
          param_interface_code: e.param_interface_code, report_name_code: e.report_name_code,
          config: e.config }
      end
    end
  end
end
