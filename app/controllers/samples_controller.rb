# frozen_string_literal: true

# M03.F02/F03 样品（B3，6 端点）。tenant-scoped + receipt FK 校验
# （lab-springboot SampleController 镜像）。
class SamplesController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  def list_samples
    render_business_envelope(service.list(receipt_id: query_param(:receiptId),
                                          keyword: query_param(:keyword)))
  end

  def get_sample
    render_camel(service.get(params[:id]))
  end

  def create_sample
    render_camel(service.create(body_params))
  end

  def update_sample
    render_camel(service.update(params[:id], body_params))
  end

  # M03.F01.I07 ext 补录：body 必须含 ext 键（契约必填，5.89）
  def update_sample_ext
    render_camel(service.update_ext(params[:id], body_params))
  end

  def delete_sample
    service.delete(params[:id])
    head :no_content
  end

  private

  def service
    @service ||= Samples::SampleService.new(current_tenant_id)
  end
end
