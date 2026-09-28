# frozen_string_literal: true

module InspectionDictionary
  # M06.F03 检测参数 —— InspectionParameter。rawName/canonicalName 缺省=name；
  # aliases jsonb 缺省 []；sourceType 缺省 official。
  class Parameters
    include Common
    include UpdateFields

    UPDATE_FIELDS = {
      'name' => %i[name truthy],
      'rawName' => %i[raw_name truthy],
      'canonicalName' => %i[canonical_name truthy],
      'methodText' => %i[method_text key],
      'aliases' => %i[aliases key],
      'unit' => %i[unit key],
      'sourceType' => %i[source_type truthy],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(keyword, source_type)
      scope = where_keyword(InspectionParameter.all, keyword)
      scope = scope.where(source_type: source_type) if present?(source_type)
      scope.order(:sort_order, :code).map { |e| dto(e) }
    end

    def create(body)
      require!(body, 'code', 'name')
      e = InspectionParameter.create!(attrs(body).merge(timestamps))
      dto(e)
    end

    def update(code, body)
      e = found!(code)
      apply_fields(e, body, UPDATE_FIELDS)
      e.updated_at = now
      e.save!
      dto(e)
    end

    def delete(code)
      found!(code).destroy!
    end

    private

    def found!(code)
      rec = InspectionParameter.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "InspectionParameter not found: #{code}" if rec.nil?

      rec
    end

    def attrs(body)
      { code: body['code'], name: body['name'],
        raw_name: body['rawName'] || body['name'],
        canonical_name: body['canonicalName'] || body['name'],
        method_text: body['methodText'], aliases: body['aliases'] || [],
        unit: body['unit'], source_type: body['sourceType'] || 'official',
        sort_order: body['sortOrder'] || 0 }
    end

    # 镜像 deserialize：aliases null/blank -> []（响应恒数组）
    def dto(e)
      { code: e.code, name: e.name, raw_name: e.raw_name, canonical_name: e.canonical_name,
        method_text: e.method_text, aliases: e.aliases.is_a?(Array) ? e.aliases : [],
        unit: e.unit, source_type: e.source_type, sort_order: e.sort_order,
        created_at: e.created_at, updated_at: e.updated_at }
    end
  end
end
