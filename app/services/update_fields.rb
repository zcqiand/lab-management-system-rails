# frozen_string_literal: true

# 字典域 services 共用的 applyUpdate 字段级镜像。mapping 形如
# { 'jsonKey' => [:column, mode] }，mode 对应 springboot mapper 的三种判定：
# - :truthy —— 值 truthy 才写（字符串字段，镜像 `if (hasText(...))` / `if body[x]`）
# - :strict —— 非 nil 才写（布尔/数值字段，镜像 `if (x != null)`）
# - :key    —— body 带键就写（允许显式置 nil，镜像 jsonb 可清空字段）
# updated_at 恒刷新由调用方负责。
module UpdateFields
  private

  def apply_fields(entity, body, mapping)
    mapping.each do |json_key, (column, mode)|
      entity.public_send("#{column}=", body[json_key]) if writable?(body, json_key, mode)
    end
  end

  def writable?(body, json_key, mode)
    value = body[json_key]
    return value ? true : false if mode == :truthy
    return !value.nil? if mode == :strict

    body.key?(json_key)
  end
end
