# frozen_string_literal: true

module Receipts
  # 接样单 DTO 与 camel→snake 字段映射（lab-springboot SampleReceiptMapper 镜像；
  # 逐字段映射的密度是移植义务，从 SampleReceiptService 拆出以守 Metrics 门）。
  module ReceiptFields
    def field_attrs(req, fields)
      fields.to_h { |f| [f.underscore, req[f]] }
    end

    def new_id
      "R-#{SecureRandom.uuid}"
    end

    def now_iso
      ApplicationRecord.now_iso
    end

    def dto(e)
      dto_commission(e).merge(dto_units(e)).merge(dto_flow(e))
    end

    private

    def dto_commission(e)
      {
        id: e.id, contract_id: e.contract_id, commission_code: e.commission_code,
        commission_date: e.commission_date,
        commission_register_code: e.commission_register_code,
        commission_register_date: e.commission_register_date,
        category_code: e.category_code, project_name: e.project_name
      }
    end

    def dto_units(e)
      {
        client_unit: e.client_unit, building_unit: e.building_unit,
        supervisor_unit: e.supervisor_unit, construction_unit: e.construction_unit,
        witness_unit: e.witness_unit, sampling_location: e.sampling_location,
        witness: e.witness, witness_phone: e.witness_phone, inspector: e.inspector,
        inspector_phone: e.inspector_phone, received_by: e.received_by,
        sample_source: e.sample_source, test_category: e.test_category,
        test_environment: e.test_environment, main_equipment: e.main_equipment,
        test_operator: e.test_operator, test_start_date: e.test_start_date,
        test_end_date: e.test_end_date, original_record_no: e.original_record_no,
        remark: e.remark
      }
    end

    def dto_flow(e)
      {
        judgment_basis: e.judgment_basis || [], testing_basis: e.testing_basis || [],
        test_parameters: e.test_parameters || [],
        flow_status: e.flow_status, flow_history: e.flow_history || [],
        last_submitted_by: e.last_submitted_by, assignee_id: e.assignee_id,
        assignee_name: e.assignee_name, planned_test_date: e.planned_test_date,
        report_code: e.report_code, report_date: e.report_date,
        conclusion: e.conclusion, result: e.result,
        issued_at: e.issued_at&.iso8601, tenant_id: e.tenant_id,
        created_at: e.created_at, updated_at: e.updated_at
      }
    end
  end
end
