# frozen_string_literal: true

# M03.F03 检测记录（B9.3，6 端点）。tenant 收口走 JWT claim
# （lab-springboot TestRecordController 镜像）。
class TestRecordsController < ApplicationController
  include JwtGuard
  include BusinessEnvelope

  def list_test_records
    render_business_envelope(service.list(sample_id: query_param(:sampleId)))
  end

  def get_test_record
    render_camel(service.get(params[:id]))
  end

  def create_test_record
    render_camel(service.create(body_params))
  end

  def update_test_record
    render_camel(service.update(params[:id], body_params))
  end

  # M03.F03 人工改判 verdict
  def set_verdict
    render_camel(service.set_verdict(params[:id], body_params['verdict']))
  end

  def delete_test_record
    service.delete(params[:id])
    head :no_content
  end

  private

  def service
    @service ||= TestRecords::TestRecordService.new(current_tenant_id)
  end
end
