# frozen_string_literal: true

module InspectionDictionary
  # M06.F02 检测对象 —— InspectionObject。必填 code/specialty/sourceProjectNo/
  # sourceProjectName/name；isOptionalForQualification 缺省 false。
  class Objects
    include Common
    include UpdateFields

    UPDATE_FIELDS = {
      'inspectionSpecialtyCode' => %i[inspection_specialty_code truthy],
      'sourceProjectNo' => %i[source_project_no truthy],
      'sourceProjectName' => %i[source_project_name truthy],
      'name' => %i[name truthy],
      'isOptionalForQualification' => %i[is_optional_for_qualification strict],
      'isOfficial' => %i[is_official strict],
      'enabled' => %i[enabled strict],
      'sortOrder' => %i[sort_order strict]
    }.freeze

    def list(keyword, specialty_code)
      scope = where_keyword(InspectionObject.all, keyword)
      scope = scope.where(inspection_specialty_code: specialty_code) if present?(specialty_code)
      scope.order(:sort_order, :code).map { |e| dto(e) }
    end

    def create(body)
      require!(body, 'code', 'inspectionSpecialtyCode', 'sourceProjectNo',
               'sourceProjectName', 'name')
      e = InspectionObject.create!(attrs(body).merge(timestamps))
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
      rec = InspectionObject.find_by(code: code)
      raise ActiveRecord::RecordNotFound, "InspectionObject not found: #{code}" if rec.nil?

      rec
    end

    def attrs(body)
      { code: body['code'], inspection_specialty_code: body['inspectionSpecialtyCode'],
        source_project_no: body['sourceProjectNo'],
        source_project_name: body['sourceProjectName'], name: body['name'],
        is_optional_for_qualification: body.fetch('isOptionalForQualification', false),
        is_official: body.fetch('isOfficial', true), enabled: body.fetch('enabled', true),
        sort_order: body['sortOrder'] || 0 }
    end

    def dto(e)
      { code: e.code, inspection_specialty_code: e.inspection_specialty_code,
        source_project_no: e.source_project_no, source_project_name: e.source_project_name,
        name: e.name, is_optional_for_qualification: e.is_optional_for_qualification,
        is_official: e.is_official, enabled: e.enabled, sort_order: e.sort_order,
        created_at: e.created_at, updated_at: e.updated_at }
    end
  end
end
