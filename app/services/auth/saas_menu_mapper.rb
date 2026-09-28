# frozen_string_literal: true

module Auth
  # saas EffectiveMenuNode → lab 契约 MenuNode 递归映射（lab-springboot SaasMenuMapper 镜像）。
  # saas label 字段是 title（2026-09-14 实测），nil 回退 code；icon nil 按 type 兜底
  # （group→resource / page→file）；子树按 sortOrder 升序（nils last，防御性再排）。
  class SaasMenuMapper
    DEFAULT_GROUP_ICON = 'resource'
    DEFAULT_PAGE_ICON = 'file'

    def map(roots)
      return [] if roots.blank?

      sort_by_order(roots).map { |n| map_node(n) }
    end

    private

    def map_node(src)
      node = {
        'id' => src['id'],
        'label' => src['title'].presence || src['code'],
        'icon' => src['icon'].presence || default_icon(src['type'])
      }
      node['path'] = src['path'] if src['path'].present?
      children = src['children']
      node['children'] = sort_by_order(children).map { |c| map_node(c) } if children.present?
      node
    end

    def sort_by_order(nodes)
      nodes.sort_by { |n| n['sortOrder'] || Float::INFINITY }
    end

    def default_icon(type)
      type == 'group' ? DEFAULT_GROUP_ICON : DEFAULT_PAGE_ICON
    end
  end
end
