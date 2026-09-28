# frozen_string_literal: true

module InspectionDictionary
  # M06 检测能力字典四实体门面 —— lab-springboot InspectionDictionaryService
  # 1:1 镜像（接口形状不变）。实体装配拆分在同级 Specialties / Objects /
  # Parameters / Standards（各自含 found!/attrs/apply/dto，守住 Metrics）。
  class InspectionDictionaryService
    def initialize
      @specialties = Specialties.new
      @objects = Objects.new
      @parameters = Parameters.new
      @standards = Standards.new
    end

    def list_specialties(keyword)
      @specialties.list(keyword)
    end

    def create_specialty(body)
      @specialties.create(body)
    end

    def update_specialty(code, body)
      @specialties.update(code, body)
    end

    def delete_specialty(code)
      @specialties.delete(code)
    end

    def list_objects(keyword, specialty_code)
      @objects.list(keyword, specialty_code)
    end

    def create_object(body)
      @objects.create(body)
    end

    def update_object(code, body)
      @objects.update(code, body)
    end

    def delete_object(code)
      @objects.delete(code)
    end

    def list_parameters(keyword, source_type)
      @parameters.list(keyword, source_type)
    end

    def create_parameter(body)
      @parameters.create(body)
    end

    def update_parameter(code, body)
      @parameters.update(code, body)
    end

    def delete_parameter(code)
      @parameters.delete(code)
    end

    def list_standards(keyword, status)
      @standards.list(keyword, status)
    end

    def create_standard(body)
      @standards.create(body)
    end

    def update_standard(code, body)
      @standards.update(code, body)
    end

    def delete_standard(code)
      @standards.delete(code)
    end
  end
end
