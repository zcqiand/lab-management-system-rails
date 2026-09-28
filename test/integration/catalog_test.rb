# frozen_string_literal: true

# M04.F06-F09 码表（catalog brands/models/specs/grades）集成测试。
# 对照 ct：inspection-catalog.test.ts / inspection-catalog-write.test.ts；
# 参照语义：lab-springboot CatalogService + InspectionCatalogMapper + InspectionCatalogController。
require 'test_helper'
require_relative 'lab_support'

class CatalogTest < ActionDispatch::IntegrationTest
  include LabSupport

  KINDS = %w[brands models specs grades].freeze

  KINDS.each do |kind|
    test "M04 #{kind} list 全量信封（page=1, pageSize=total, items 数组）" do
      assert_list_envelope(kind)
    end

    test "M04 #{kind} list keyword 过滤命中自造行" do
      assert_keyword_filter(kind)
    end

    test "M04 #{kind} create -> 200 字段齐全（sortOrder 缺省 0）" do
      assert_create_defaults(kind)
    end

    test "M04 #{kind} create 缺 code -> 400 BAD_REQUEST" do
      post "/api/catalog/#{kind}", params: { name: 'no-code' },
                                   headers: auth_header, as: :json
      assert_response :bad_request
      assert_equal 'BAD_REQUEST', json(response)['code']
    end
  end

  # 401 用例放在两个 KINDS.each 之间，防止 Style/CombinableLoops 合并建议
  test 'M04 无 token -> 401' do
    get '/api/catalog/brands'
    assert_response :unauthorized
  end

  KINDS.each do |kind|
    test "M04 #{kind} update -> 200 改名（部分字段）" do
      assert_update_renames(kind)
    end

    test "M04 #{kind} update 查无 -> 404" do
      put "/api/catalog/#{kind}/no-such-code", params: { name: 'x' },
                                               headers: auth_header, as: :json
      assert_response :not_found
      assert_equal 'NOT_FOUND', json(response)['code']
    end

    test "M04 #{kind} delete -> 204，重复删 -> 404" do
      assert_delete_then_repeat_not_found(kind)
    end

    test "M04 #{kind} tenant 隔离：TENANT_B 看不到 TENANT_A 的行（update 404）" do
      assert_tenant_isolation(kind)
    end
  end

  private

  def create_entry(kind, code, name, object_code = nil)
    Catalog::CatalogService.new.create(
      kind.to_s.singularize.to_sym, LabSupport::TENANT_A,
      { 'code' => code, 'name' => name, 'inspectionObjectCode' => object_code }
    )
  end

  def assert_list_envelope(kind)
    get "/api/catalog/#{kind}", headers: auth_header
    assert_response :success
    body = json(response)
    %w[page pageSize total items].each { |k| assert body.key?(k), "缺 #{k}" }
    assert_equal 1, body['page']
    assert_equal body['total'], body['pageSize']
    assert_kind_of Array, body['items']
  end

  def assert_keyword_filter(kind)
    seed = seed_dictionary!
    code = uniq_code("ct-#{kind[0]}")
    create_entry(kind, code, "picker-#{code}", seed[:object].code)

    get "/api/catalog/#{kind}", params: { keyword: code }, headers: auth_header
    assert_response :success
    body = json(response)
    assert_equal 1, body['total']
    assert_equal code, body['items'].first['code']
    assert_equal "picker-#{code}", body['items'].first['name']
  end

  def assert_create_defaults(kind)
    seed = seed_dictionary!
    code = uniq_code("ct-#{kind[0]}")

    post "/api/catalog/#{kind}",
         params: { code: code, name: "entry #{code}", inspectionObjectCode: seed[:object].code },
         headers: auth_header, as: :json
    assert_response :success
    assert_created_body(json(response), code, seed[:object].code)
  end

  def assert_created_body(body, code, object_code)
    assert_equal code, body['code']
    assert_equal "entry #{code}", body['name']
    assert_equal object_code, body['inspectionObjectCode']
    assert_equal 0, body['sortOrder']
    assert_equal LabSupport::TENANT_A, body['tenantId']
    assert body['createdAt'].present?
  end

  def assert_update_renames(kind)
    code = uniq_code("ct-#{kind[0]}")
    create_entry(kind, code, 'old')

    put "/api/catalog/#{kind}/#{code}", params: { name: 'renamed' },
                                        headers: auth_header, as: :json
    assert_response :success
    assert_equal 'renamed', json(response)['name']
  end

  def assert_delete_then_repeat_not_found(kind)
    code = uniq_code("ct-#{kind[0]}")
    create_entry(kind, code, 'doomed')

    delete "/api/catalog/#{kind}/#{code}", headers: auth_header
    assert_response :no_content

    delete "/api/catalog/#{kind}/#{code}", headers: auth_header
    assert_response :not_found
  end

  def assert_tenant_isolation(kind)
    code = uniq_code("ct-#{kind[0]}")
    create_entry(kind, code, 'mine')

    get "/api/catalog/#{kind}", params: { keyword: code },
                                headers: auth_header(LabSupport::TENANT_B)
    assert_response :success
    assert_equal 0, json(response)['total']

    put "/api/catalog/#{kind}/#{code}", params: { name: 'steal' },
                                        headers: auth_header(LabSupport::TENANT_B), as: :json
    assert_response :not_found
  end
end
