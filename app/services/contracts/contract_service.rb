# frozen_string_literal: true

module Contracts
  # M02.F01 合同域（lab-springboot ContractService/ContractMapper 镜像）。
  # tenant-scoped（V012）；keyword 过滤 contract_code/project_name；status ∈ {active, archived}；
  # 排序 updatedAt DESC, contractCode（repo.filter JPQL 镜像）。
  class ContractService
    STATUSES = %w[active archived].freeze
    DEFAULT_STATUS = 'active'

    # fromCreate 全字段（contractCode 含内）；applyUpdate 不碰 contractCode
    UPDATE_FIELDS = %w[
      clientUnit projectName projectLocation constructionUnit inspectionSpecialtyCode
      buildingUnit supervisorUnit inspectionPerson inspectionPhone witnessUnit witness
      witnessPhone contactPerson contactPhone entrustedDate status
    ].freeze
    CREATE_FIELDS = %w[contractCode] + UPDATE_FIELDS

    def initialize(tenant_id)
      @tenant_id = tenant_id
    end

    def list(keyword: nil, status: nil)
      scope = Contract.where(tenant_id: @tenant_id)
      scope = filter_keyword(scope, keyword)
      scope = scope.where(status: status) if status
      scope.order(updated_at: :desc, contract_code: :asc).map { |e| dto(e) }
    end

    def get(id)
      dto(find!(id))
    end

    def create(req)
      now = now_iso
      attrs = field_attrs(req, CREATE_FIELDS)
      contract = Contract.create!(
        attrs.merge(id: new_id, tenant_id: @tenant_id,
                    status: status_of(req), created_at: now, updated_at: now)
      )
      dto(contract)
    end

    def update(id, req)
      contract = find!(id)
      apply_update(contract, req, now_iso)
      contract.save!
      dto(contract)
    end

    def delete(id)
      find!(id).destroy!
    end

    def self.status_of(req)
      status = req['status']
      return DEFAULT_STATUS if status.nil?

      raise ArgumentError, "Unexpected value '#{status}'" unless STATUSES.include?(status)

      status
    end

    private

    def find!(id)
      Contract.find_by(tenant_id: @tenant_id, id: id) or
        raise ActiveRecord::RecordNotFound, "Contract not found: #{id}"
    end

    def filter_keyword(scope, keyword)
      keyword = keyword.to_s
      return scope if keyword.empty?

      like = "%#{keyword.downcase}%"
      scope.where('(LOWER(contract_code) LIKE :k OR LOWER(project_name) LIKE :k)', k: like)
    end

    def status_of(req)
      self.class.status_of(req)
    end

    def apply_update(contract, req, now)
      field_attrs(req, UPDATE_FIELDS).compact.each { |col, v| contract[col] = v }
      contract.updated_at = now
    end

    def field_attrs(req, fields)
      fields.to_h { |f| [f.underscore, req[f]] }
    end

    def new_id
      "C-#{SecureRandom.uuid}"
    end

    def now_iso
      ApplicationRecord.now_iso
    end

    def dto(e)
      {
        id: e.id, contract_code: e.contract_code, client_unit: e.client_unit,
        project_name: e.project_name, project_location: e.project_location,
        construction_unit: e.construction_unit,
        inspection_specialty_code: e.inspection_specialty_code,
        building_unit: e.building_unit, supervisor_unit: e.supervisor_unit,
        inspection_person: e.inspection_person, inspection_phone: e.inspection_phone,
        witness_unit: e.witness_unit, witness: e.witness, witness_phone: e.witness_phone,
        contact_person: e.contact_person, contact_phone: e.contact_phone,
        entrusted_date: e.entrusted_date, status: e.status, tenant_id: e.tenant_id,
        created_at: e.created_at, updated_at: e.updated_at
      }
    end
  end
end
