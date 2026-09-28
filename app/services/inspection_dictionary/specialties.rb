# frozen_string_literal: true

module InspectionDictionary
  # M06.F01 检测专项 —— InspectionSpecialty。officialNo NOT NULL（ct T11 实证）。
  class Specialties
    include Common
    include UpdateFields

    # 镜像 mapper.applyUpdate 的字段判定
    UPDATE_FIELDS = {
      'officialNo' => %i[official_no truthy],
      'name' => %i[name truthy],
      'isOfficial' => %i[is_official strict],
      'enabled' => %i[enabled strict],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(keyword)
      where_keyword(InspectionSpecialty.all, keyword)
        .order(:sort_order, :code).map { |e| dto(e) }
    end

    def create(body)
      require!(body, 'code', 'officialNo', 'name')
      e = InspectionSpecialty.create!(attrs(body).merge(timestamps))
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
      rec = InspectionSpecialty.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "InspectionSpecialty not found: #{code}" if rec.nil?

      rec
    end

    def attrs(body)
      { code: body['code'], official_no: body['officialNo'], name: body['name'],
        is_official: body.fetch('isOfficial', true), enabled: body.fetch('enabled', true),
        sort_order: body['sortOrder'] || 0 }
    end

    def dto(e)
      { code: e.code, official_no: e.official_no, name: e.name,
        is_official: e.is_official, enabled: e.enabled, sort_order: e.sort_order,
        created_at: e.created_at, updated_at: e.updated_at }
    end
  end
end
