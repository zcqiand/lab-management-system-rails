# frozen_string_literal: true

# M06.F06 技术要求（三元复合主键 object × parameter × judgmentStandard；tenant 隔离）
# 集成测试。对照 ct：technical-requirements.test.ts / technical-requirements-write.test.ts；
# 参照语义：lab-springboot TechnicalRequirementService + TechnicalRequirementMapper。
# list 返回裸数组（4 过滤），get/update/delete 按三键 + tenant 寻址。
require 'test_helper'
require_relative 'lab_support'

class TechnicalRequirementsTest < ActionDispatch::IntegrationTest
  include LabSupport

  test 'M06.F06 list 返回裸数组' do
    get '/api/technical-requirements', headers: auth_header

    assert_response :success
    assert_kind_of Array, json(response)
  end

  test 'M06.F06 create -> 200 缺省 valueType/comparison/judgmentMode/verificationStatus' do
    seed = seed_dictionary!

    post '/api/technical-requirements',
         params: tr_body(seed),
         headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal seed[:object].code, body['inspectionObjectCode']
    assert_equal seed[:standard].code, body['judgmentStandardCode']
    assert_equal 'numeric', body['valueType']
    assert_equal '≥', body['comparison']
    assert_equal 'manual', body['judgmentMode']
    assert_equal 'draft', body['verificationStatus']
    assert_equal 0, body['sortOrder']
    assert_equal LabSupport::TENANT_A, body['tenantId']
  end

  test 'M06.F06 create 缺 judgmentStandardCode -> 400' do
    seed = seed_dictionary!

    post '/api/technical-requirements',
         params: { inspectionObjectCode: seed[:object].code,
                   inspectionParameterCode: seed[:parameter].code },
         headers: auth_header, as: :json

    assert_response :bad_request
    assert_equal 'BAD_REQUEST', json(response)['code']
  end

  test 'M06.F06 list 按 object/parameter/standard/status 过滤 + tenant 收口' do
    seed = seed_dictionary!
    create_tr(seed)

    get '/api/technical-requirements',
        params: { inspectionObjectCode: seed[:object].code, verificationStatus: 'draft' },
        headers: auth_header
    assert_response :success
    assert_equal 1, json(response).length

    get '/api/technical-requirements',
        params: { inspectionObjectCode: seed[:object].code, verificationStatus: 'verified' },
        headers: auth_header
    assert_equal 0, json(response).length

    # tenant 隔离：TENANT_B 查不到
    get '/api/technical-requirements',
        params: { inspectionObjectCode: seed[:object].code },
        headers: auth_header(LabSupport::TENANT_B)
    assert_equal 0, json(response).length
  end

  test 'M06.F06 get 三键寻址 -> 200；查无 -> 404' do
    seed = seed_dictionary!
    create_tr(seed)

    get "/api/technical-requirements/#{seed[:object].code}/#{seed[:parameter].code}/#{seed[:standard].code}",
        headers: auth_header
    assert_response :success
    assert_equal '≥ 42.5 MPa', json(response)['targetValue']

    get "/api/technical-requirements/nope/#{seed[:parameter].code}/#{seed[:standard].code}",
        headers: auth_header
    assert_response :not_found
    assert_equal 'NOT_FOUND', json(response)['code']
  end

  test 'M06.F06 update 改 unit（部分更新）-> 200' do
    seed = seed_dictionary!
    create_tr(seed)

    put "/api/technical-requirements/#{seed[:object].code}/#{seed[:parameter].code}/#{seed[:standard].code}",
        params: { unit: 'MPa' },
        headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal 'MPa', body['unit']
    assert_equal 'draft', body['verificationStatus']
  end

  test 'M06.F06 update 查无 -> 404' do
    seed = seed_dictionary!

    put "/api/technical-requirements/nope/#{seed[:parameter].code}/#{seed[:standard].code}",
        params: { unit: 'x' },
        headers: auth_header(LabSupport::TENANT_B), as: :json

    assert_response :not_found
  end

  test 'M06.F06 delete -> 204，重复删 -> 404' do
    seed = seed_dictionary!
    create_tr(seed)
    path = "/api/technical-requirements/#{seed[:object].code}/#{seed[:parameter].code}/#{seed[:standard].code}"

    delete path, headers: auth_header
    assert_response :no_content

    delete path, headers: auth_header
    assert_response :not_found
  end

  test 'M06.F06 无 token -> 401' do
    get '/api/technical-requirements'
    assert_response :unauthorized
  end

  private

  def tr_body(seed)
    { inspectionObjectCode: seed[:object].code, inspectionParameterCode: seed[:parameter].code,
      judgmentStandardCode: seed[:standard].code, requirement: '≥ 42.5 MPa',
      targetValue: '≥ 42.5 MPa' }
  end

  def create_tr(seed)
    TechnicalRequirement::TechnicalRequirementService.new.create(
      tr_body(seed).transform_keys(&:to_s), LabSupport::TENANT_A
    )
  end
end
