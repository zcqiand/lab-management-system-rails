# frozen_string_literal: true

module TestRecords
  # M03.F03 检测记录数据录入域（lab-springboot TestRecordService/TestRecordMapper 镜像）。
  # tenant-scoped；create 四必填（IAE→400）；sample/parameter FK 走 DB 约束（→400）；
  # 排序 updatedAt DESC, id。
  class TestRecordService
    UPDATE_FIELDS = %w[
      parameterCode standardCode requirementCode requirement result verdict
    ].freeze
    CREATE_FIELDS = %w[sampleId] + UPDATE_FIELDS

    def initialize(tenant_id)
      @tenant_id = tenant_id
    end

    def list(sample_id: nil)
      scope = TestRecord.where(tenant_id: @tenant_id)
      scope = scope.where(sample_id: sample_id) if sample_id.present?
      scope.order(updated_at: :desc, id: :asc).map { |e| dto(e) }
    end

    def get(id)
      dto(find!(id))
    end

    def create(req)
      missing = %w[sampleId parameterCode requirement result].select { |f| req[f].nil? }
      raise ArgumentError, 'sampleId, parameterCode, requirement and result are required' if missing.any?

      now = now_iso
      record = TestRecord.create!(field_attrs(req, CREATE_FIELDS).merge(
                                    id: new_id, tenant_id: @tenant_id,
                                    created_at: now, updated_at: now
                                  ))
      dto(record)
    end

    def update(id, req)
      record = find!(id)
      field_attrs(req, UPDATE_FIELDS).compact.each { |col, v| record[col] = v }
      record.updated_at = now_iso
      record.save!
      dto(record)
    end

    # 人工改判 verdict（M03.F05/F06 报告流程可能触发）；verdict 直写（可置 null）
    def set_verdict(id, verdict)
      record = find!(id)
      record.verdict = verdict
      record.updated_at = now_iso
      record.save!
      dto(record)
    end

    def delete(id)
      find!(id).destroy!
    end

    private

    def find!(id)
      TestRecord.find_by(tenant_id: @tenant_id, id: id) or
        raise ActiveRecord::RecordNotFound, "TestRecord not found: #{id}"
    end

    def field_attrs(req, fields)
      fields.to_h { |f| [f.underscore, req[f]] }
    end

    def new_id
      "TR-#{SecureRandom.uuid}"
    end

    def now_iso
      ApplicationRecord.now_iso
    end

    def dto(e)
      {
        id: e.id, tenant_id: e.tenant_id, sample_id: e.sample_id,
        parameter_code: e.parameter_code, standard_code: e.standard_code,
        requirement_code: e.requirement_code, requirement: e.requirement,
        result: e.result, verdict: e.verdict, created_at: e.created_at,
        updated_at: e.updated_at
      }
    end
  end
end
