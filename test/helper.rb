# frozen_string_literal: true

require "minitest/autorun"

require_relative "harness/fn"

# trace 适配器门控 —— 与 java-spring 的 -Dharness.trace=true / python 的
# TRACE_MAP=1 同一约定：只有 suite 的 trace_cmd 会带 TRACE_MAP=1 进来，
# 普通测试运行不挂 reporter、不写 .state/trace.json。
#
# 挂载走 minitest 插件协议（Minitest.reporter 仅在 Minitest.run 内存在）：
# helper 加载期只注册 plugin_trace_map_init，init_plugins 阶段才真正 << reporter。
# Rails 仓 init 后：把 harness 的 require_relative + 本注册块 splice 进
# rails 生成的 test/test_helper.rb 尾部（环境加载之后）。
Minitest.define_singleton_method(:plugin_trace_map_init) do |*_options|
  next unless ENV["TRACE_MAP"] == "1"

  require_relative "harness/trace_reporter"
  Minitest.reporter << Harness::TraceReporter.new
end
Minitest.extensions << "trace_map"
