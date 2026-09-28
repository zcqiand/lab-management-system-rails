# frozen_string_literal: true

# M06 检测字典 4 实体（specialties/objects/parameters/standards）CRUD +
# 4 类 junction link/unlink/list 集成测试。
# 对照 ct：inspection-dictionary.test.ts / inspection-dictionary-write.test.ts；
# 参照语义：lab-springboot InspectionDictionaryService/Mapper + InspectionJunctionService。
require 'test_helper'
require_relative 'lab_support'

class InspectionDictionaryTest < ActionDispatch::IntegrationTest
  include LabSupport

  # === specialties ===

  test 'M06.F01 specialty list 信封 + create/update/delete' do
    get '/api/inspection/specialties', headers: auth_header
    assert_response :success
    body = json(response)
    %w[page pageSize total items].each { |k| assert body.key?(k), "缺 #{k}" }
    assert_equal 1, body['page']

    code = uniq_code('ct-sp')
    post '/api/inspection/specialties',
         params: { code: code, officialNo: "ON-#{code}", name: "sp #{code}" },
         headers: auth_header, as: :json
    assert_response :success
    sp = json(response)
    assert_equal code, sp['code']
    assert sp['isOfficial'], 'isOfficial 缺省 true'
    assert sp['enabled'], 'enabled 缺省 true'

    put "/api/inspection/specialties/#{code}",
        params: { name: 'renamed' }, headers: auth_header, as: :json
    assert_response :success
    assert_equal 'renamed', json(response)['name']

    delete "/api/inspection/specialties/#{code}", headers: auth_header
    assert_response :no_content
  end

  test 'M06.F01 specialty create 缺 officialNo -> 400（ct T11 实证 NOT NULL）' do
    post '/api/inspection/specialties',
         params: { code: uniq_code('ct-sp'), name: 'no officialNo' },
         headers: auth_header, as: :json
    assert_response :bad_request
  end

  test 'M06.F01 specialty delete 查无 -> 404' do
    delete '/api/inspection/specialties/no-such-sp', headers: auth_header
    assert_response :not_found
  end

  # === objects ===

  test 'M06.F02 object create 必填 5 字段 + list 按 specialtyCode 过滤' do
    seed = seed_dictionary!
    code = uniq_code('ct-obj')

    post '/api/inspection/objects',
         params: { code: code, name: "obj #{code}",
                   inspectionSpecialtyCode: seed[:specialty].code,
                   sourceProjectNo: code, sourceProjectName: "proj #{code}" },
         headers: auth_header, as: :json
    assert_response :success
    body = json(response)
    assert_equal seed[:specialty].code, body['inspectionSpecialtyCode']
    assert_equal false, body['isOptionalForQualification'], '缺省 false'

    get '/api/inspection/objects',
        params: { inspectionSpecialtyCode: seed[:specialty].code }, headers: auth_header
    assert_response :success
    # seed_dictionary! 已建 1 个同 specialty 的 object，加上本次新建共 2
    assert_equal 2, json(response)['total']

    delete "/api/inspection/objects/#{code}", headers: auth_header
    assert_response :no_content
  end

  test 'M06.F02 object create 缺 sourceProjectNo -> 400' do
    seed = seed_dictionary!

    post '/api/inspection/objects',
         params: { code: uniq_code('ct-obj'), name: 'x',
                   inspectionSpecialtyCode: seed[:specialty].code,
                   sourceProjectName: 'proj' },
         headers: auth_header, as: :json
    assert_response :bad_request
  end

  # === parameters ===

  test 'M06.F03 parameter create 缺省 rawName/canonicalName=name，aliases=[]，sourceType=official' do
    code = uniq_code('ct-prm')

    post '/api/inspection/parameters',
         params: { code: code, name: "prm #{code}" },
         headers: auth_header, as: :json
    assert_response :success
    body = json(response)
    assert_equal "prm #{code}", body['rawName']
    assert_equal "prm #{code}", body['canonicalName']
    assert_equal [], body['aliases']
    assert_equal 'official', body['sourceType']

    put "/api/inspection/parameters/#{code}",
        params: { aliases: %w[pH 酸碱度] }, headers: auth_header, as: :json
    assert_response :success
    assert_equal %w[pH 酸碱度], json(response)['aliases']

    delete "/api/inspection/parameters/#{code}", headers: auth_header
    assert_response :no_content
  end

  test 'M06.F03 parameter list sourceType 过滤' do
    seed = seed_dictionary!

    get '/api/inspection/parameters',
        params: { sourceType: 'official' }, headers: auth_header
    assert_response :success
    items = json(response)['items']
    assert(items.all? { |i| i['sourceType'] == 'official' })
    assert(items.any? { |i| i['code'] == seed[:parameter].code })
  end

  # === standards ===

  test 'M06.F04 standard create 缺省 status=active + update 改 version' do
    code = uniq_code('ct-std')

    post '/api/inspection/standards',
         params: { code: code, name: "std #{code}" },
         headers: auth_header, as: :json
    assert_response :success
    assert_equal 'active', json(response)['status']

    put "/api/inspection/standards/#{code}",
        params: { version: '2024-1' }, headers: auth_header, as: :json
    assert_response :success
    assert_equal '2024-1', json(response)['version']

    delete "/api/inspection/standards/#{code}", headers: auth_header
    assert_response :no_content
  end

  test 'M06.F04 standard list status 过滤' do
    seed = seed_dictionary!

    get '/api/inspection/standards', params: { status: 'active' }, headers: auth_header
    assert_response :success
    items = json(response)['items']
    assert(items.all? { |i| i['status'] == 'active' })
    assert(items.any? { |i| i['code'] == seed[:standard].code })

    get '/api/inspection/standards', params: { status: 'superseded' }, headers: auth_header
    assert_equal 0, json(response)['total']
  end

  # === 4 类 junction ===

  test 'M06 specialty-object link/unlink 幂等 + list 过滤' do
    seed = seed_dictionary!
    body = { inspectionSpecialtyCode: seed[:specialty].code,
             inspectionObjectCode: seed[:object].code }

    post '/api/inspection/links/specialty-object', params: body, headers: auth_header, as: :json
    assert_response :no_content

    get '/api/inspection/links/specialty-object',
        params: { inspectionSpecialtyCode: seed[:specialty].code }, headers: auth_header
    assert_response :success
    assert_equal 1, json(response)['total']

    delete '/api/inspection/links/specialty-object', params: body, headers: auth_header, as: :json
    assert_response :no_content
    delete '/api/inspection/links/specialty-object', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06 object-parameter link（qualificationLevel 缺省 QUALIFIED）+ unlink 幂等' do
    seed = seed_dictionary!
    body = { inspectionObjectCode: seed[:object].code,
             inspectionParameterCode: seed[:parameter].code }

    post '/api/inspection/links/object-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content

    get '/api/inspection/links/object-parameter', params: body, headers: auth_header
    assert_response :success
    assert_equal 'QUALIFIED', json(response)['items'].first['qualificationLevel']

    delete '/api/inspection/links/object-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content
    delete '/api/inspection/links/object-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06 object-standard link（role 必填，缺 -> 400）+ list 按 role 过滤' do
    seed = seed_dictionary!
    body = { inspectionObjectCode: seed[:object].code,
             inspectionStandardCode: seed[:standard].code, role: 'JUDGMENT' }

    post '/api/inspection/links/object-standard', params: body, headers: auth_header, as: :json
    assert_response :no_content

    post '/api/inspection/links/object-standard',
         params: { inspectionObjectCode: seed[:object].code,
                   inspectionStandardCode: seed[:standard].code },
         headers: auth_header, as: :json
    assert_response :bad_request

    get '/api/inspection/links/object-standard',
        params: { inspectionObjectCode: seed[:object].code, role: 'JUDGMENT' },
        headers: auth_header
    assert_equal 1, json(response)['total']

    get '/api/inspection/links/object-standard',
        params: { inspectionObjectCode: seed[:object].code, role: 'TESTING' },
        headers: auth_header
    assert_equal 0, json(response)['total']

    delete '/api/inspection/links/object-standard', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06 standard-parameter link/unlink 幂等' do
    seed = seed_dictionary!
    body = { inspectionStandardCode: seed[:standard].code,
             inspectionParameterCode: seed[:parameter].code }

    post '/api/inspection/links/standard-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content

    get '/api/inspection/links/standard-parameter',
        params: { inspectionStandardCode: seed[:standard].code }, headers: auth_header
    assert_equal 1, json(response)['total']

    delete '/api/inspection/links/standard-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content
    delete '/api/inspection/links/standard-parameter', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M06 无 token -> 401' do
    get '/api/inspection/specialties'
    assert_response :unauthorized
  end
end
