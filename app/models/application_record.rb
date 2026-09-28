# frozen_string_literal: true

# lab 家族底座。created_at/updated_at 是 TEXT 列（V001 起历史设计，区别于 saas
# 家族的 timestamptz），由应用层维护 ISO-8601 UTC 串（镜像 lab-springboot
# nowIso()）—— 关 Rails 自动 touch 防格式分叉。
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  self.record_timestamps = false

  # 镜像 lab-springboot nowIso()：OffsetDateTime.now(UTC).ISO_OFFSET_DATE_TIME
  def self.now_iso
    Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%:z')
  end
end
