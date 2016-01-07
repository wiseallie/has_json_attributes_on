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

            attrs.each do |attr_name, attr_type_key|
              attribute attr_name.to_sym, AXIOMS[attr_type_key]
            end

            def self.inspect
              _attrs = attribute_set.instance_variable_get("@attributes").map{|x| [x.name, x.type.inspect].join(":")}.join(", ")
              "<#{name}  type => #{type_name}  attribute_set => [#{_attrs}]>"
            end

            def self.to_s
              self.inspect
            end
          end
          return model.send(:const_set, klazz_name, klazz)
        end
      end

      def initialize(model, data_column, attrs = {})
        @virtus_model = self.class.build_virtus_model(model, data_column, attrs)
      end

      def type_cast_from_user(value)
        @virtus_model.new(value)
      end

      def type_cast_from_database(value)
        @virtus_model.new(super(value))
      end

      def type_cast_for_database(value)
        if value.is_a?(@virtus_model)
          ::ActiveSupport::JSON.encode(value)
        else
          super
        end
      end
    end
  end
end
