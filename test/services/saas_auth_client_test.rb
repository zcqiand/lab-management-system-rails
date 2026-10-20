# frozen_string_literal: true

require 'test_helper'

module Auth
  # 5.119：token() 返回形状钉——真方法直测，传输层单点替身（post_json），
  # 替身回包=saas IdP Oauth::TokenService#issue 经 render_camel 的真 wire 形状。
  # 既有 auth_flow_test 的 stub_token 整体替换 token()（替身直接回 TokenResponse，
  # 比真方法"更好"），掩蔽了裸 Hash 缝（消费侧 t.access_token NoMethodError）——
  # 本文件是该 client 真 wire 映射的唯一在案断言面。
  class SaasAuthClientTest < ActiveSupport::TestCase
    # saas IdP oauth_controller#token 真 wire：camel 键 + 冗余键（userId/clientId）
    REAL_TOKEN_WIRE = {
      'accessToken' => 'at-wire', 'refreshToken' => 'rt-wire',
      'tokenType' => 'Bearer', 'expiresIn' => 3600, 'scope' => 'menus.read',
      'userId' => 'saas-u-1', 'clientId' => 'lab-management'
    }.freeze

    setup do
      @client = Auth::SaasAuthClient.new
      @sent = {}
      client = @client
      sent = @sent
      client.define_singleton_method(:post_json) do |path, body|
        sent[:path] = path
        sent[:body] = body
        REAL_TOKEN_WIRE
      end
    end

    test 'token returns TokenResponse mapped from saas camel wire' do
      t = @client.token('refresh_token', refresh_token: 'rt-old')

      assert_instance_of Auth::SaasAuthClient::TokenResponse, t
      assert_equal 'at-wire', t.access_token
      assert_equal 'rt-wire', t.refresh_token
      assert_equal 'Bearer', t.token_type
      assert_equal 3600, t.expires_in
      assert_equal 'menus.read', t.scope
    end

    test 'token sends camel-case grant body to oauth endpoint' do
      @client.token('authorization_code', code: 'c-1', redirect_uri: 'http://lab/cb')

      assert_equal '/api/v1/oauth/token', @sent[:path]
      assert_equal 'authorization_code', @sent[:body][:grantType]
      assert_equal 'c-1', @sent[:body][:code]
      assert_equal 'http://lab/cb', @sent[:body][:redirectUri]
    end

    test 'token omits absent optional fields and keeps refresh token' do
      @client.token('refresh_token', refresh_token: 'rt-old')

      refute @sent[:body].key?(:code)
      refute @sent[:body].key?(:redirectUri)
      assert_equal 'rt-old', @sent[:body][:refreshToken]
    end
  end
end
