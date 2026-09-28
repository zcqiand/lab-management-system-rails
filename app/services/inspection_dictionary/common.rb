# frozen_string_literal: true

module InspectionDictionary
  # 字典四实体 services 的共享小件：keyword 过滤 / 必填键 / 应用层时间戳。
  module Common
    private

    def now
      ApplicationRecord.now_iso
    end

    def timestamps
      { created_at: now, updated_at: now }
    end

    # 镜像 requireNonBlank 的建路径语义：键缺失 -> IAE 400
    def require!(body, *keys)
      keys.each { |k| raise ArgumentError, "#{k} is required" if body[k].nil? }
    end

    def present?(value)
      return !value.strip.empty? if value.is_a?(String)

      !value.nil?
    end

    # 镜像 mapper 列表查询：keyword ILIKE code OR name（blank = 不过滤）
    def where_keyword(scope, keyword)
      return scope unless present?(keyword)

      scope.where('LOWER(code) LIKE :kw OR LOWER(name) LIKE :kw', kw: "%#{keyword.downcase}%")
    end
  end
end
