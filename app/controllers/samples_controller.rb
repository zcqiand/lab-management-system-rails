# frozen_string_literal: true

# M03.F02/F03 样品（B3，6 端点）。tenant-scoped + receipt FK 校验
# （lab-springboot SampleController 镜像）。
class SamplesController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  # @impl M03.F03.I01 (book anchor xr-know-012)
  def list_samples
    render_business_envelope(service.list(receipt_id: query_param(:receiptId),
                                          keyword: query_param(:keyword)))
  end

  # @impl M03.F03.I02 (book anchor xr-know-012)
  def get_sample
    render_camel(service.get(params[:id]))
  end

  # @impl M03.F03.I03 (book anchor xr-know-012)
  def create_sample
    render_camel(service.create(body_params))
  end

  # @impl M03.F03.I04 (book anchor xr-know-012)
  def update_sample
    render_camel(service.update(params[:id], body_params))
  end

  # M03.F01.I07 ext 补录：body 必须含 ext 键（契约必填，5.89）
  # @impl M03.F01.I07 (book anchor xr-know-012)
  def update_sample_ext
    render_camel(service.update_ext(params[:id], body_params))
  end

  # @impl M03.F03.I05 (book anchor xr-know-012)
  def delete_sample
    service.delete(params[:id])
    head :no_content
  end

  private

  def service
    @service ||= Samples::SampleService.new(current_tenant_id)
  end
end
