require  'virtus'
require  'default_value_for'
module HasJsonAttributesOn
  extend ActiveSupport::Concern

  AXIOMS = {
    'Boolean' => Axiom::Types::Boolean,
    'String'  => Axiom::Types::String,
    'Decimal' => Axiom::Types::Decimal,
    'Date'    => Axiom::Types::Date,
    'DateTime'=> Axiom::Types::DateTime,
    'Time'    => Axiom::Types::Time,
    'Float'   => Axiom::Types::Float,
    'Integer' => Axiom::Types::Integer,
    'Object'  => Axiom::Types::Object,
    'Array'   => Axiom::Types::Array,
    'Set'     => Axiom::Types::Set,
    'Hash'    => Axiom::Types::Hash
  }

  module Type
    module JsonType
      extend ActiveSupport::Concern

      included do
        attr_accessor :virtus_model
      end

      class_methods do

        def validate_virtus_model_attr_options!(model, attrs)
          raise "Model: #{model}, attributes must be a Hash of key:attribute_name and value:attribute_type" unless attrs.is_a?(Hash)
          attrs.each do |k,v|
            raise "Model: #{model}, key:#{k} should be a valid hash key" if k.to_s.include?(" ");
            raise "Model: #{model}, value for key:#{k} should be one of: #{AXIOMS.keys}" unless v.in?(AXIOMS.keys)
          end
        end

        def build_virtus_model(model, data_column,  attrs = {})
          type_name = self.name
          validate_virtus_model_attr_options!(model, attrs)
          klazz_name = data_column.to_s.camelize + "DynamicType"

          klazz = Class.new do
            include Virtus.model
            cattr_accessor :type_name, :klazz_name

            attrs.each do |attr_name, attr_type_key|
              attribute attr_name.to_sym, AXIOMS[attr_type_key]
            end

            def  self.type_name
              @type_name
            end

            def  self.type_name=(v)
              @type_name = v
            end

            def  self.type_name
              @klazz_name
            end

            def  self.type_name=(v)
              @klazz_name = v
            end

            def self.inspect
              _attrs = attribute_set.instance_variable_get("@attributes").map{|x| [x.name, x.type.inspect].join(":")}.join(", ")
              "<#{name}  type => #{type_name}  attribute_set => [#{_attrs}]>"
            end

            def self.to_s
              self.inspect
            end
          end
          klazz.klazz_name = klazz_name
          klazz.type_name = type_name
          return model.send(:const_set, klazz_name, klazz)
        end

        def build_serializer(model, data_column, attrs = {})
          type_name = self.name
          validate_virtus_model_attr_options!(model, attrs)
          klazz_name = data_column.to_s.camelize + "DynamicTypeSerializer"
          virtus_model = build_virtus_model(model, data_column, attrs)

          klazz = Class.new() do
            cattr_accessor :klazz_name, :virtus_model, :model, :data_column, :attrs

            def self.is_my_type?(v)
              v.is_a?(virtus_model)
            end

            def  self.attrs
              @attrs
            end

            def  self.attrs=(v)
              @attrs = v
            end

            def  self.data_column
              @data_column
            end

            def  self.data_column=(v)
              @data_column = v
            end

            def  self.model
              @model
            end

            def  self.model=(v)
              @model = v
            end

            def  self.klazz_name
              @klazz_name
            end

            def  self.klazz_name=(v)
              @klazz_name = v
            end

            def self.virtus_model=(v)
              @virtus_model = v
            end

            def self.virtus_model
              @virtus_model
            end

            # TODO Figure out why this is misbehaving!!!!
            def self.load(value)
              begin
                if (value.is_a?(String))
                  value = JSON.load(value)
                end
                # return @virtus_model.new(value)
                return value
              rescue Exception => e
                Rails.logger.warn("#{name} for model #{model.name} threw an exception within self.load, #{e.class} => #{e.message}")
                # return @virtus_model.new
                return {}
              end
            end

            def self.dump(value)
              ActiveSupport::JSON.encode(value)
            end

            def self.inspect
              "<#{name} \n virtus_model => #{self.virtus_model.inspect} \n model => #{self.model.inspect} \n data_column => #{self.data_column} \n attrs => #{self.attrs.inspect} >"
            end

            def self.to_s
              self.inspect
            end
          end

          klazz.virtus_model = virtus_model
          klazz.klazz_name = klazz_name
          klazz.model = model
          klazz.data_column = data_column
          klazz.attrs = attrs

          return model.send(:const_set, klazz_name, klazz)
        end
      end
    end
  end
end
