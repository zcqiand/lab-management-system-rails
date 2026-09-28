# frozen_string_literal: true

module Samples
  # M03.F02/F03 样品域（lab-springboot SampleService/SampleMapper 镜像）。
  # tenant-scoped + receipt FK 校验（NSEE→404，不是 FK→400 —— service 层显式查）；
  # keyword 过滤 sample_code/sample_name；排序 createdAt DESC, sampleCode。
  class SampleService
    UPDATE_FIELDS = %w[
      sampleName model specification grade brand manufacturer structuralPart
      representQuantity sampleQuantity batchNumber supplyUnit arrivalDate samplingDate
      curingCondition age ext remark
    ].freeze
    CREATE_FIELDS = %w[receiptId sampleCode] + UPDATE_FIELDS

    def initialize(tenant_id)
      @tenant_id = tenant_id
    end

    def list(receipt_id: nil, keyword: nil)
      scope = Sample.where(tenant_id: @tenant_id)
      scope = scope.where(receipt_id: receipt_id) if receipt_id.present?
      scope = filter_keyword(scope, keyword)
      scope.order(created_at: :desc, sample_code: :asc).map { |e| dto(e) }
    end

    def get(id)
      dto(find!(id))
    end

    def create(req)
      receipt_id = req['receiptId']
      unless SampleReceipt.exists?(tenant_id: @tenant_id, id: receipt_id)
        raise ActiveRecord::RecordNotFound, "Receipt not found: #{receipt_id}"
      end

      now = now_iso
      sample = Sample.create!(field_attrs(req, CREATE_FIELDS).merge(
                                id: new_id, tenant_id: @tenant_id,
                                ext: req['ext'] || {}, created_at: now, updated_at: now
                              ))
      dto(sample)
    end

    def update(id, req)
      sample = find!(id)
      field_attrs(req, UPDATE_FIELDS - ['ext']).compact.each { |col, v| sample[col] = v }
      sample.ext = req['ext'] unless req['ext'].nil?
      sample.updated_at = now_iso
      sample.save!
      dto(sample)
    end

    # M03.F01.I07 ext 补录：整体替换（合并是前端职责）；契约 ext 必填（5.89，缺省 IAE→400）
    def update_ext(id, req)
      raise ArgumentError, 'ext is required' if req.nil? || req['ext'].nil?

      sample = find!(id)
      sample.ext = req['ext']
      sample.updated_at = now_iso
      sample.save!
      dto(sample)
    end

    def delete(id)
      find!(id).destroy!
    end

    private

    def find!(id)
      Sample.find_by(tenant_id: @tenant_id, id: id) or
        raise ActiveRecord::RecordNotFound, "Sample not found: #{id}"
    end

    def filter_keyword(scope, keyword)
      keyword = keyword.to_s
      return scope if keyword.empty?

      like = "%#{keyword.downcase}%"
      scope.where('(LOWER(sample_code) LIKE :k OR LOWER(sample_name) LIKE :k)', k: like)
    end

    def field_attrs(req, fields)
      fields.to_h { |f| [f.underscore, req[f]] }
    end

    def new_id
      "S-#{SecureRandom.uuid}"
    end

    def now_iso
      ApplicationRecord.now_iso
    end

    def dto(e)
      {
        id: e.id, receipt_id: e.receipt_id, sample_code: e.sample_code,
        sample_name: e.sample_name, model: e.model, specification: e.specification,
        grade: e.grade, brand: e.brand, manufacturer: e.manufacturer,
        structural_part: e.structural_part, represent_quantity: e.represent_quantity,
        sample_quantity: e.sample_quantity, batch_number: e.batch_number,
        supply_unit: e.supply_unit, arrival_date: e.arrival_date,
        sampling_date: e.sampling_date, curing_condition: e.curing_condition, age: e.age,
        ext: e.ext || {}, remark: e.remark, tenant_id: e.tenant_id,
        created_at: e.created_at, updated_at: e.updated_at
      }
    end
  end
end
