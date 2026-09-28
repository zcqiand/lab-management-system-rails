# frozen_string_literal: true

# M06 检测字典 4 类 junction 的 12 个 action（link/unlink/list）——
# 自 InspectionDictionaryController 拆出（Metrics/ClassLength）。
# link/unlink 恒 204；junction list 用短信封 page=1/pageSize=total。
# 依赖宿主 controller 的 `junction` 私有方法。
module InspectionDictionaryLinks
  def link_specialty_object
    junction.link_specialty_object(request.request_parameters)
    head :no_content
  end

  def unlink_specialty_object
    junction.unlink_specialty_object(request.request_parameters)
    head :no_content
  end

  def list_specialty_object_links
    render_junction_envelope(
      junction.list_specialty_object_links(params[:inspectionSpecialtyCode])
    )
  end

  def link_object_parameter
    junction.link_object_parameter(request.request_parameters)
    head :no_content
  end

  def unlink_object_parameter
    body = request.request_parameters
    junction.unlink_object_parameter(body['inspectionObjectCode'],
                                     body['inspectionParameterCode'])
    head :no_content
  end

  def list_object_parameter_links
    render_junction_envelope(
      junction.list_object_parameter_links(params[:inspectionObjectCode],
                                           params[:inspectionParameterCode])
    )
  end

  def link_object_standard
    junction.link_object_standard(request.request_parameters)
    head :no_content
  end

  def unlink_object_standard
    body = request.request_parameters
    junction.unlink_object_standard(body['inspectionObjectCode'],
                                    body['inspectionStandardCode'], body['role'])
    head :no_content
  end

  def list_object_standard_links
    render_junction_envelope(
      junction.list_object_standard_links(params[:inspectionObjectCode], params[:role])
    )
  end

  def link_standard_parameter
    junction.link_standard_parameter(request.request_parameters)
    head :no_content
  end

  def unlink_standard_parameter
    junction.unlink_standard_parameter(request.request_parameters)
    head :no_content
  end

  def list_standard_parameter_links
    render_junction_envelope(
      junction.list_standard_parameter_links(params[:inspectionStandardCode],
                                             params[:inspectionParameterCode])
    )
  end

  private

  def junction
    @junction ||= InspectionDictionary::InspectionJunctionService.new
  end

  # junction list 信封：page 恒 1（镜像 springboot 200Response 硬编码）
  def render_junction_envelope(items)
    render_camel({ items: items, page: 1, page_size: items.size, total: items.size })
  end
end
