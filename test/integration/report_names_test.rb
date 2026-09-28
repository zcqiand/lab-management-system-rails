# frozen_string_literal: true

# M06.F07 报告名称（平台级字典 CRUD :code + 3 类 junction link）集成测试。
# 对照 ct：report-names.test.ts / report-names-write.test.ts；
# 参照语义：lab-springboot InspectionReportNameService/Mapper + InspectionJunctionService。
require 'test_helper'
require_relative 'lab_support'

class ReportNamesTest < ActionDispatch::IntegrationTest
  include LabSupport

  test 'M06.F07 list 全量信封（page=1, pageSize=total）' do
    get '/api/report-names', headers: auth_header

    assert_response :success
    body = json(response)
    %w[page pageSize total items].each { |k| assert body.key?(k), "缺 #{k}" }
    assert_equal 1, body['page']
    assert_equal body['total'], body['pageSize']
    assert_kind_of Array, body['items']
  end

  test 'M06.F07 list keyword 过滤（code/name）' do
    code = uniq_code('ct-rn')
    create_rn(code, "needle-#{code}")

    get '/api/report-names', params: { keyword: code }, headers: auth_header

    assert_response :success
    body = json(response)
    assert_equal 1, body['total']
    assert_equal code, body['items'].first['code']
    assert_equal [], body['items'].first['extFields'] # extFields 缺省 []
  end

  test 'M06.F07 get 查无 -> 404' do
    get '/api/report-names/no-such-rn', headers: auth_header

    assert_response :not_found
    assert_equal 'NOT_FOUND', json(response)['code']
  end

  test 'M06.F07 create -> 200（extFields 回显数组，缺省 []）' do
    code = uniq_code('ct-rn')

    post '/api/report-names',
         params: { code: code, name: "rn #{code}",
                   extFields: [{ key: 'pH', label: 'pH 值' }] },
         headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal code, body['code']
    assert_equal [{ 'key' => 'pH', 'label' => 'pH 值' }], body['extFields']
    assert_equal 0, body['sortOrder']
  end

  test 'M06.F07 create 缺 name -> 400' do
    post '/api/report-names',
         params: { code: uniq_code('ct-rn') },
         headers: auth_header, as: :json

    assert_response :bad_request
  end

  test 'M06.F07 update 改 name -> 200' do
    code = uniq_code('ct-rn')
    create_rn(code)

    put "/api/report-names/#{code}",
        params: { name: 'renamed' },
        headers: auth_header, as: :json

    assert_response :success
    assert_equal 'renamed', json(response)['name']
  end

  test 'M06.F07 delete -> 204，重复删 -> 404' do
    code = uniq_code('ct-rn')
    create_rn(code)

    delete "/api/report-names/#{code}", headers: auth_header
    assert_response :no_content

    delete "/api/report-names/#{code}", headers: auth_header
    assert_response :not_found
  end

  # === 3 类 junction link/unlink/list ===

  test 'M06.F07 object link -> 204，unlink 幂等 204，list 信封回显' do
    seed = seed_dictionary!
    rn = uniq_code('ct-rn')
    create_rn(rn)

    post '/api/report-names/links/object',
         params: { inspectionObjectCode: seed[:object].code, reportNameCode: rn },
         headers: auth_header, as: :json
    assert_response :no_content

    get '/api/report-names/links/object',
        params: { inspectionObjectCode: seed[:object].code, reportNameCode: rn },
        headers: auth_header
    assert_response :success
    body = json(response)
    assert_equal 1, body['total']
    assert_equal 1, body['page']
    assert_equal rn, body['items'].first['reportNameCode']

    delete '/api/report-names/links/object',
           params: { inspectionObjectCode: seed[:object].code, reportNameCode: rn },
           headers: auth_header, as: :json
    assert_response :no_content

    # 幂等：重复 unlink 未命中同样 204
    delete '/api/report-names/links/object',
           params: { inspectionObjectCode: seed[:object].code, reportNameCode: rn },
           headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06.F07 parameter link/unlink 204 + link 缺字段 -> 400' do
    seed = seed_dictionary!
    rn = uniq_code('ct-rn')
    create_rn(rn)

    post '/api/report-names/links/parameter',
         params: { reportNameCode: rn, inspectionParameterCode: seed[:parameter].code },
         headers: auth_header, as: :json
    assert_response :no_content

    post '/api/report-names/links/parameter',
         params: { reportNameCode: rn },
         headers: auth_header, as: :json
    assert_response :bad_request

    delete '/api/report-names/links/parameter',
           params: { reportNameCode: rn, inspectionParameterCode: seed[:parameter].code },
           headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06.F07 standard link（role 必填）-> 204 + unlink 幂等 + list 按 role 过滤' do
    seed = seed_dictionary!
    rn = uniq_code('ct-rn')
    create_rn(rn)
    body = { reportNameCode: rn, inspectionStandardCode: seed[:standard].code, role: 'JUDGMENT' }

    post '/api/report-names/links/standard', params: body, headers: auth_header, as: :json
    assert_response :no_content

    get '/api/report-names/links/standard',
        params: { reportNameCode: rn, role: 'JUDGMENT' }, headers: auth_header
    assert_response :success
    assert_equal 1, json(response)['total']

    get '/api/report-names/links/standard',
        params: { reportNameCode: rn, role: 'TESTING' }, headers: auth_header
    assert_equal 0, json(response)['total']

    delete '/api/report-names/links/standard', params: body, headers: auth_header, as: :json
    assert_response :no_content

    delete '/api/report-names/links/standard', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06.F07 无 token -> 401' do
    get '/api/report-names'
    assert_response :unauthorized
  end

  private

  def create_rn(code, name = "rn #{code}")
    ReportNames::InspectionReportNameService.new.create(
      'code' => code, 'name' => name
    )
  end
end
