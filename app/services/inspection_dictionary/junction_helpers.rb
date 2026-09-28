# frozen_string_literal: true

module InspectionDictionary
  # 8 个 junction service 共享的小件（link 校验 / upsert / list 过滤）。
  module JunctionHelpers
    private

    # 镜像 InspectionJunctionService.requireNonBlank
    def require_non_blank!(*values)
      values.each do |v|
        raise ArgumentError, 'junction link fields must be non-null' if v.nil?
        raise ArgumentError, 'junction link fields must be non-blank' if v.is_a?(String) && v.strip.empty?
      end
    end

    # upsert：同 PK 已存在则整行覆盖（含 created_at —— springboot save=merge 语义）
    def upsert!(model, key_attrs, payload)
      now = ApplicationRecord.now_iso
      rec = model.find_by(key_attrs) || model.new(key_attrs)
      rec.assign_attributes(payload)
      rec.created_at = now
      rec.updated_at = now
      rec.save!
    end

    def filter(scope, attrs)
      value = attrs.values.first
      present?(value) ? scope.where(attrs) : scope
    end

    def present?(value)
      return !value.strip.empty? if value.is_a?(String)

      !value.nil?
    end
  end
end
