# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'
require_relative '../lib/api_support/json_camelize_key'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LabManagementSystemRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # 用户面「今日/时间呈现」统一本地时区（+0800；tracker 5.113 人裁 2026-10-18）——
    # AR 存储仍 UTC（default_timezone 缺省），序列化经 Time.zone → 与 Date.today 对齐，
    # 消除每日本地 00:00-08:00 窗内 summary todayTestCount 少计
    config.time_zone = 'Beijing'
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
