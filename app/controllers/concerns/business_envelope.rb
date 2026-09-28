# frozen_string_literal: true

# 业务域（contracts/samples/receipts/test-records）列表信封 + 404 语义 concern。
# - 信封：page=1/pageSize=20 缺省（2026-09-16 T11 live 实证 1-based，lab-ct
#   contracts.test.ts "分页 defaults 全等" 锁定）；items 全量回（springboot controller
#   只 echo page/pageSize 不切片，total = items.size）—— 与 ApplicationController
#   render_paginated（saas 裸 UUID 分页切片口径）是有意差异。
# - 404：业务域 id 带前缀（C-/R-/S-/TR-），ApplicationController#bad_uuid_param 的
#   裸 UUID 启发式会把前缀 id 折成 400 —— 此处覆写 rescue 顺序，查无一律 404
#   （springboot NoSuchElementException 语义）。
module BusinessEnvelope
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      render_error(:not_found, 'NOT_FOUND', e.message)
    end
  end

  private

  # {items, page, pageSize, total} 信封；page/pageSize 仅 echo 不切片（参照实现实测）
  def render_business_envelope(items)
    page = params.include?(:page) ? params[:page].to_i : 1
    page_size = params.include?(:pageSize) ? params[:pageSize].to_i : 20
    render_camel({ items: items, page: page, page_size: page_size, total: items.size })
  end

  # query param 归一：缺省/空串 → nil（springboot null 语义）
  def query_param(name)
    value = params[name]
    value.nil? || value == '' ? nil : value
  end

  # JSON 请求体（HashWithIndifferentAccess；缺 body → {}）
  def body_params
    request.request_parameters
  end

  # springboot 枚举 query/body 参数反序列化镜像：未知值 → 400（IAE）
  def enum_param!(value, allowed)
    return nil if value.nil?

    raise ArgumentError, "Unexpected value '#{value}'" unless allowed.include?(value)

    value
  end
end
