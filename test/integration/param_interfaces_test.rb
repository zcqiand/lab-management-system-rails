# frozen_string_literal: true

# M10 参数接口（平台级字典 CRUD :code + junction link）集成测试。
# 对照 ct：param-interfaces.test.ts / param-interfaces-write.test.ts；
# 参照语义：lab-springboot ParamInterfaceService/Mapper + InspectionJunctionService。
require 'test_helper'
require_relative 'lab_support'

class ParamInterfacesTest < ActionDispatch::IntegrationTest
  include LabSupport

  test 'M10 list 全量信封（page=1, pageSize=total）' do
    get '/api/param-interfaces', headers: auth_header

    assert_response :success
    body = json(response)
    %w[page pageSize total items].each { |k| assert body.key?(k), "缺 #{k}" }
    assert_equal 1, body['page']
    assert_equal body['total'], body['pageSize']
    assert_kind_of Array, body['items']
  end

  test 'M10 get 查无 -> 404' do
    get '/api/param-interfaces/no-such-pi', headers: auth_header

    assert_response :not_found
    assert_equal 'NOT_FOUND', json(response)['code']
  end

  test 'M10 create -> 200（config 缺省 {}，componentPath 必填）' do
    code = uniq_code('ct-pi')

    post '/api/param-interfaces',
         params: { code: code, name: "pi #{code}", componentPath: 'cards/default',
                   config: { layout: 'grid' } },
         headers: auth_header, as: :json

    assert_response :success
    body = json(response)
    assert_equal code, body['code']
    assert_equal 'cards/default', body['componentPath']
    assert_equal({ 'layout' => 'grid' }, body['config'])
    assert_equal 0, body['sortOrder']
  end

  test 'M10 create 缺 componentPath -> 400（ct 实证：宽松 mock 曾掩盖）' do
    post '/api/param-interfaces',
         params: { code: uniq_code('ct-pi'), name: 'no path' },
         headers: auth_header, as: :json

    assert_response :bad_request
    assert_equal 'BAD_REQUEST', json(response)['code']
  end

  test 'M10 update 改 name -> 200' do
    code = uniq_code('ct-pi')
    create_pi(code)

    put "/api/param-interfaces/#{code}",
        params: { name: 'renamed' },
        headers: auth_header, as: :json

    assert_response :success
    assert_equal 'renamed', json(response)['name']
  end

  test 'M10 delete -> 204，重复删 -> 404' do
    code = uniq_code('ct-pi')
    create_pi(code)

    delete "/api/param-interfaces/#{code}", headers: auth_header
    assert_response :no_content

    delete "/api/param-interfaces/#{code}", headers: auth_header
    assert_response :not_found
  end

  test 'M10 link -> 204，unlink 幂等 204，links list 信封回显' do
    seed = seed_dictionary!
    body = { inspectionParameterCode: seed[:parameter].code,
             paramInterfaceCode: create_pi(uniq_code('ct-pi')),
             config: { mode: 'input' } }

    post '/api/param-interfaces/links', params: body, headers: auth_header, as: :json
    assert_response :no_content

    get '/api/param-interfaces/links',
        params: { inspectionParameterCode: body[:inspectionParameterCode] },
        headers: auth_header
    assert_response :success
    links = json(response)
    assert_equal 1, links['total']
    assert_equal 1, links['page']
    assert_equal({ 'mode' => 'input' }, links['items'].first['config'])

    delete '/api/param-interfaces/links', params: body, headers: auth_header, as: :json
    assert_response :no_content

    # 幂等：重复 unlink 未命中同样 204
    delete '/api/param-interfaces/links', params: body, headers: auth_header, as: :json
    assert_response :no_content
  end

  test 'M10 link 缺 paramInterfaceCode -> 400' do
    seed = seed_dictionary!

    post '/api/param-interfaces/links',
         params: { inspectionParameterCode: seed[:parameter].code },
         headers: auth_header, as: :json

    assert_response :bad_request
  end

  test 'M10 无 token -> 401' do
    get '/api/param-interfaces'
    assert_response :unauthorized
  end

  private

  def create_pi(code)
    ParamInterface::ParamInterfaceService.new.create(
      'code' => code, 'name' => "pi #{code}", 'componentPath' => 'cards/default'
    )
    code
  end
end
