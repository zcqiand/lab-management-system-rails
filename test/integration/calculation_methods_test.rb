# frozen_string_literal: true

# M06.F05 计算方法（复合主键 objectCode × parameterCode）集成测试。
# 对照 ct：calculation-methods.test.ts / calculation-methods-write.test.ts；
# 参照语义：lab-springboot CalculationMethodService + CalculationMethodMapper。
# 平台级字典（无 tenant_id），list 返回裸数组（不分页）。
require 'test_helper'
require_relative 'lab_support'

class CalculationMethodsTest < ActionDispatch::IntegrationTest
  include LabSupport

  test 'M06.F05 list 返回裸数组（不分页信封）' do
    get '/api/calculation-methods', headers: auth_header

    assert_response :success
    assert_kind_of Array, json(response)
  end

  test 'M06.F05 list 双过滤 objectCode + parameterCode' do
    seed = seed_dictionary!
    create_cm(seed[:object].code, seed[:parameter].code)

    get '/api/calculation-methods',
        params: { inspectionObjectCode: seed[:object].code, inspectionParameterCode: seed[:parameter].code },
        headers: auth_header

    assert_response :success
    body = json(response)
    assert_equal 1, body.length
    assert_equal seed[:object].code, body.first['inspectionObjectCode']
    assert_equal 'value * 2', body.first['formula']
    assert_equal 'manual', body.first['algorithmType']
    assert_equal 1, body.first['specimenCount']
  end

  test 'M06.F05 get 按复合主键 -> 200，查无 -> 404' do
    seed = seed_dictionary!
    create_cm(seed[:object].code, seed[:parameter].code)

    get "/api/calculation-methods/#{seed[:object].code}/#{seed[:parameter].code}",
        headers: auth_header
    assert_response :success
    assert_equal seed[:parameter].code, json(response)['inspectionParameterCode']

    get "/api/calculation-methods/nope/#{seed[:parameter].code}", headers: auth_header
    assert_response :not_found
    assert_equal 'NOT_FOUND', json(response)['code']
  end

  test 'M06.F05 create -> 200 缺省 algorithmType=manual specimenCount=1 sortOrder=0' do
    seed = seed_dictionary!

    post '/api/calculation-methods',
         params: { inspectionObjectCode: seed[:object].code,
                   inspectionParameterCode: seed[:parameter].code,
                   formula: 'value * 2' },
         headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal seed[:object].code, body['inspectionObjectCode']
    assert_equal 'value * 2', body['formula']
    assert_equal 'manual', body['algorithmType']
    assert_equal 1, body['specimenCount']
    assert_equal 0, body['sortOrder']
  end

  test 'M06.F05 create 缺 parameterCode -> 400 BAD_REQUEST' do
    seed = seed_dictionary!

    post '/api/calculation-methods',
         params: { inspectionObjectCode: seed[:object].code },
         headers: auth_header, as: :json

    assert_response :bad_request
    assert_equal 'BAD_REQUEST', json(response)['code']
  end

  test 'M06.F05 update 改 formula -> 200（部分更新不动主键）' do
    seed = seed_dictionary!
    create_cm(seed[:object].code, seed[:parameter].code)

    put "/api/calculation-methods/#{seed[:object].code}/#{seed[:parameter].code}",
        params: { formula: 'renamed' },
        headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal 'renamed', body['formula']
    assert_equal 'manual', body['algorithmType']
  end

  test 'M06.F05 update 查无 -> 404' do
    put '/api/calculation-methods/nope/nope2',
        params: { formula: 'x' },
        headers: auth_header, as: :json

    assert_response :not_found
  end

  test 'M06.F05 delete -> 204，重复删 -> 404' do
    seed = seed_dictionary!
    create_cm(seed[:object].code, seed[:parameter].code)

    delete "/api/calculation-methods/#{seed[:object].code}/#{seed[:parameter].code}",
           headers: auth_header
    assert_response :no_content

    delete "/api/calculation-methods/#{seed[:object].code}/#{seed[:parameter].code}",
           headers: auth_header
    assert_response :not_found
  end

  test 'M06.F05 无 token -> 401' do
    get '/api/calculation-methods'
    assert_response :unauthorized
  end

  private

  def create_cm(object_code, parameter_code)
    CalculationMethod::CalculationMethodService.new.create(
      'inspectionObjectCode' => object_code, 'inspectionParameterCode' => parameter_code,
      'formula' => 'value * 2'
    )
  end
end
