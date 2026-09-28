# frozen_string_literal: true

module Auth
  # 菜单快照不可用 → 503 MENUS_UNAVAILABLE（lab-springboot GlobalExceptionHandler 镜像）。
  # 独立文件：ApplicationController 的 rescue_from 在控制器加载期解析本常量，
  # 定义放在 auth_service.rb 内会因 zeitwerk 文件约定加载顺序炸 NameError。
  class MenusUnavailable < StandardError; end
end
