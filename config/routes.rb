# frozen_string_literal: true

# 路由面 = lib/generated/api_manifest.json 的 1:1 镜像（SSOT 是 lab-shared openapi.yaml）。
# action 名 = operationId 去掉 tag 前缀后 underscore；test/contracts/route_parity_test.rb 逐条对账。
# lab 契约路径无 /v1 前缀（/api/... 直挂，镜像 lab-springboot）。
Rails.application.routes.draw do
  get '/health', to: 'health#show'

  scope '/api', defaults: { format: :json } do
    # tag: frontend-bind-meta
    get '/_frontend-bind/snapshot', to: 'frontend_bind_meta#get_frontend_bind_snapshot'

    # tag: auth
    post '/auth/login',         to: 'auth#login'
    post '/auth/logout',        to: 'auth#logout'
    get  '/auth/me',            to: 'auth#get_current_user'
    get  '/auth/menus',         to: 'auth#get_menus'
    post '/auth/native-login',  to: 'auth#native_login'
    get  '/auth/permissions',   to: 'auth#get_permissions'
    post '/auth/refresh',       to: 'auth#refresh'
    get  '/auth/sso/authorize', to: 'auth#sso_authorize'
    post '/auth/sso/callback',  to: 'auth#sso_callback'
    post '/auth/switch-tenant', to: 'auth#switch_tenant'

    # tag: calculation-methods（复合主键 objectCode × parameterCode）
    get    '/calculation-methods', to: 'calculation_methods#list_calculation_methods'
    post   '/calculation-methods', to: 'calculation_methods#create_calculation_method'
    get    '/calculation-methods/:inspection_object_code/:inspection_parameter_code',
           to: 'calculation_methods#get_calculation_method'
    put '/calculation-methods/:inspection_object_code/:inspection_parameter_code',
        to: 'calculation_methods#update_calculation_method'
    delete '/calculation-methods/:inspection_object_code/:inspection_parameter_code',
           to: 'calculation_methods#delete_calculation_method'

    # tag: catalog（字典四件套 brands/models/specs/grades，:code 是业务码）
    get    '/catalog/brands', to: 'catalog#list_brands'
    post   '/catalog/brands', to: 'catalog#create_brand'
    put    '/catalog/brands/:code', to: 'catalog#update_brand'
    delete '/catalog/brands/:code', to: 'catalog#delete_brand'
    get    '/catalog/grades', to: 'catalog#list_grades'
    post   '/catalog/grades', to: 'catalog#create_grade'
    put    '/catalog/grades/:code', to: 'catalog#update_grade'
    delete '/catalog/grades/:code', to: 'catalog#delete_grade'
    get    '/catalog/models', to: 'catalog#list_models'
    post   '/catalog/models', to: 'catalog#create_model'
    put    '/catalog/models/:code', to: 'catalog#update_model'
    delete '/catalog/models/:code', to: 'catalog#delete_model'
    get    '/catalog/specs', to: 'catalog#list_specs'
    post   '/catalog/specs', to: 'catalog#create_spec'
    put    '/catalog/specs/:code', to: 'catalog#update_spec'
    delete '/catalog/specs/:code', to: 'catalog#delete_spec'

    # tag: contracts
    get    '/contracts',      to: 'contracts#list_contracts'
    post   '/contracts',      to: 'contracts#create_contract'
    get    '/contracts/:id',  to: 'contracts#get_contract'
    put    '/contracts/:id',  to: 'contracts#update_contract'
    delete '/contracts/:id',  to: 'contracts#delete_contract'

    # tag: inspection-dictionary（四实体 CRUD + 四类 junction link）
    get    '/inspection/specialties', to: 'inspection_dictionary#list_specialties'
    post   '/inspection/specialties', to: 'inspection_dictionary#create_specialty'
    put    '/inspection/specialties/:code', to: 'inspection_dictionary#update_specialty'
    delete '/inspection/specialties/:code', to: 'inspection_dictionary#delete_specialty'
    get    '/inspection/objects', to: 'inspection_dictionary#list_objects'
    post   '/inspection/objects', to: 'inspection_dictionary#create_object'
    put    '/inspection/objects/:code', to: 'inspection_dictionary#update_object'
    delete '/inspection/objects/:code', to: 'inspection_dictionary#delete_object'
    get    '/inspection/parameters', to: 'inspection_dictionary#list_parameters'
    post   '/inspection/parameters', to: 'inspection_dictionary#create_parameter'
    put    '/inspection/parameters/:code', to: 'inspection_dictionary#update_parameter'
    delete '/inspection/parameters/:code', to: 'inspection_dictionary#delete_parameter'
    get    '/inspection/standards', to: 'inspection_dictionary#list_standards'
    post   '/inspection/standards', to: 'inspection_dictionary#create_standard'
    put    '/inspection/standards/:code', to: 'inspection_dictionary#update_standard'
    delete '/inspection/standards/:code', to: 'inspection_dictionary#delete_standard'
    post   '/inspection/links/specialty-object', to: 'inspection_dictionary#link_specialty_object'
    delete '/inspection/links/specialty-object', to: 'inspection_dictionary#unlink_specialty_object'
    get    '/inspection/links/specialty-object', to: 'inspection_dictionary#list_specialty_object_links'
    post   '/inspection/links/object-parameter', to: 'inspection_dictionary#link_object_parameter'
    delete '/inspection/links/object-parameter', to: 'inspection_dictionary#unlink_object_parameter'
    get    '/inspection/links/object-parameter', to: 'inspection_dictionary#list_object_parameter_links'
    post   '/inspection/links/object-standard', to: 'inspection_dictionary#link_object_standard'
    delete '/inspection/links/object-standard', to: 'inspection_dictionary#unlink_object_standard'
    get    '/inspection/links/object-standard', to: 'inspection_dictionary#list_object_standard_links'
    post   '/inspection/links/standard-parameter', to: 'inspection_dictionary#link_standard_parameter'
    delete '/inspection/links/standard-parameter', to: 'inspection_dictionary#unlink_standard_parameter'
    get    '/inspection/links/standard-parameter', to: 'inspection_dictionary#list_standard_parameter_links'

    # tag: param-interfaces
    get    '/param-interfaces', to: 'param_interfaces#list_param_interfaces'
    post   '/param-interfaces', to: 'param_interfaces#create_param_interface'
    get    '/param-interfaces/:code', to: 'param_interfaces#get_param_interface'
    put    '/param-interfaces/:code', to: 'param_interfaces#update_param_interface'
    delete '/param-interfaces/:code', to: 'param_interfaces#delete_param_interface'
    post   '/param-interfaces/links', to: 'param_interfaces#link_param_interface'
    delete '/param-interfaces/links', to: 'param_interfaces#unlink_param_interface'
    get    '/param-interfaces/links', to: 'param_interfaces#list_param_interface_links'

    # tag: receipts（接样单 + 7 态流程 act 端点）
    get    '/receipts', to: 'receipts#list_receipts'
    post   '/receipts', to: 'receipts#create_receipt'
    get    '/receipts/:id', to: 'receipts#get_receipt'
    put    '/receipts/:id', to: 'receipts#update_receipt'
    delete '/receipts/:id', to: 'receipts#delete_receipt'
    get    '/receipts/:id/history', to: 'receipts#get_receipt_history'
    put    '/receipts/:id/task', to: 'receipts#assign_task'
    post   '/receipts/receiving/act', to: 'receipts#act_flow_receiving'
    post   '/receipts/assigning/act', to: 'receipts#act_flow_assigning'
    post   '/receipts/data-entry/act', to: 'receipts#act_flow_data_entry'
    post   '/receipts/review/act', to: 'receipts#act_flow_review'
    post   '/receipts/approve/act', to: 'receipts#act_flow_approve'
    post   '/receipts/issuance/act', to: 'receipts#act_flow_issuance'
    post   '/receipts/archived/act', to: 'receipts#act_flow_archived'

    # tag: report-names
    get    '/report-names', to: 'report_names#list_report_names'
    post   '/report-names', to: 'report_names#create_report_name'
    get    '/report-names/:code', to: 'report_names#get_report_name'
    put    '/report-names/:code', to: 'report_names#update_report_name'
    delete '/report-names/:code', to: 'report_names#delete_report_name'
    post   '/report-names/links/object', to: 'report_names#link_object_report_name'
    delete '/report-names/links/object', to: 'report_names#unlink_object_report_name'
    get    '/report-names/links/object', to: 'report_names#list_object_report_name_links'
    post   '/report-names/links/parameter', to: 'report_names#link_report_name_parameter'
    delete '/report-names/links/parameter', to: 'report_names#unlink_report_name_parameter'
    get    '/report-names/links/parameter', to: 'report_names#list_report_name_parameter_links'
    post   '/report-names/links/standard', to: 'report_names#link_report_name_standard'
    delete '/report-names/links/standard', to: 'report_names#unlink_report_name_standard'
    get    '/report-names/links/standard', to: 'report_names#list_report_name_standard_links'

    # tag: samples
    get    '/samples',     to: 'samples#list_samples'
    post   '/samples',     to: 'samples#create_sample'
    get    '/samples/:id', to: 'samples#get_sample'
    put    '/samples/:id', to: 'samples#update_sample'
    delete '/samples/:id', to: 'samples#delete_sample'
    put    '/samples/:id/ext', to: 'samples#update_sample_ext'

    # tag: summary
    get '/summary',       to: 'summary#get_report_summary'
    get '/summary/stats', to: 'summary#get_dashboard_stats'

    # tag: technical-requirements（复合主键 objectCode × parameterCode × standardCode）
    get    '/technical-requirements', to: 'technical_requirements#list_technical_requirements'
    post   '/technical-requirements', to: 'technical_requirements#create_technical_requirement'
    get    '/technical-requirements/:inspection_object_code/:inspection_parameter_code/:judgment_standard_code',
           to: 'technical_requirements#get_technical_requirement'
    put '/technical-requirements/:inspection_object_code/:inspection_parameter_code/:judgment_standard_code',
        to: 'technical_requirements#update_technical_requirement'
    delete '/technical-requirements/:inspection_object_code/:inspection_parameter_code/:judgment_standard_code',
           to: 'technical_requirements#delete_technical_requirement'

    # tag: test-records
    get    '/test-records',     to: 'test_records#list_test_records'
    post   '/test-records',     to: 'test_records#create_test_record'
    get    '/test-records/:id', to: 'test_records#get_test_record'
    put    '/test-records/:id', to: 'test_records#update_test_record'
    delete '/test-records/:id', to: 'test_records#delete_test_record'
    patch  '/test-records/:id/verdict', to: 'test_records#set_verdict'
  end
end
