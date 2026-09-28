# frozen_string_literal: true

module InspectionDictionary
  # M06.F04 检测标准 —— InspectionStandard。status 缺省 active。
  class Standards
    include Common
    include UpdateFields

    UPDATE_FIELDS = {
      'name' => %i[name truthy],
      'version' => %i[version key],
      'status' => %i[status truthy],
      'sourceDocumentId' => %i[source_document_id key],
      'sourceHash' => %i[source_hash key],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(keyword, status)
      scope = where_keyword(InspectionStandard.all, keyword)
      scope = scope.where(status: status) if present?(status)
      scope.order(:sort_order, :code).map { |e| dto(e) }
    end

    def create(body)
      require!(body, 'code', 'name')
      e = InspectionStandard.create!(attrs(body).merge(timestamps))
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
      rec = InspectionStandard.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "InspectionStandard not found: #{code}" if rec.nil?

      rec
    end

    def attrs(body)
      { code: body['code'], name: body['name'], version: body['version'],
        status: body['status'] || 'active', source_document_id: body['sourceDocumentId'],
        source_hash: body['sourceHash'], sort_order: body['sortOrder'] || 0 }
    end

    def dto(e)
      { code: e.code, name: e.name, version: e.version, status: e.status,
        source_document_id: e.source_document_id, source_hash: e.source_hash,
        sort_order: e.sort_order, created_at: e.created_at, updated_at: e.updated_at }
    end
  end
end
