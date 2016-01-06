require 'rails'
require 'active_record/connection_adapters/postgresql/oid/json'
require 'active_record/connection_adapters/postgresql/oid/jsonb'
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

  SUPPORTED_DB_SQL_TYPES = %w(json jsonb)
  VALUE_TYPE_CLASSES = {
    'json' => 'HasJsonAttributesOn::Type::Json',
    'jsonb' => 'HasJsonAttributesOn::Type::Jsonb'
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

        def build_virtus_model(model, data_column, attrs = {})
          validate_virtus_model_attr_options!(model, attrs)
          klazz_name = data_column.to_s.camelize + "DynamicType"

          klazz = Class.new do
            include Virtus.model

            attrs.each do |attr_name, attr_type_key|
              attribute attr_name.to_sym, AXIOMS[attr_type_key]
            end

            def self.inspect
              _attrs = attribute_set.instance_variable_get("@attributes").map{|x| [x.name, x.type.inspect].join(":")}.join(", ")
              "<#{name}  type =>HasJsonAttributesOn::Type::JsonType  attribute_set => [#{_attrs}]>"
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
    class Jsonb < ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Jsonb
      include JsonType
    end
    class Json < ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Json
      include JsonType
    end
  end

  included do
    extend Forwardable
  end

  class_methods do

    def inherited(subclass)
      super
      if self.respond_to?(:has_json_attributes_on) && self.respond_to?(:_json_attributes_on) && self._json_attributes_on.present?
        self._json_attributes_on.each do |data_column, options|
          subclass.has_json_attributes_on(data_column, options[:accessors])
        end
      end
    end

    def has_json_attributes_on(data_column = :data, accessors = {})
      validated_data_column, data_column_sql_type = validate_json_attributes_data_column!(data_column)
      validated_accessors = validate_dynamic_accessors!(accessors)
      build_json_attributes(validated_data_column, data_column_sql_type, validated_accessors)
    end

    private

    def validate_json_attributes_data_column!(data_column)
      data_column = data_column.to_sym
      unless columns.map(&:name).include?(data_column.to_s)
        raise ArgumentError,  "Model: #{name}#has_json_attributes_on, data_column: #{data_column} does not exist as a column in database"
      end

      data_column_sql_type = columns.detect{|x| x.name.to_s == data_column.to_s}.sql_type
      unless data_column_sql_type.in?(SUPPORTED_DB_SQL_TYPES)
        raise ArgumentError,  "Model: #{name}#has_json_attributes_on, data_column: #{data_column} is of sql type: #{data_column_sql_type}, supported types are:#{SUPPORTED_DB_SQL_TYPES}"
      end
      return [data_column, data_column_sql_type]
    end


    def validate_dynamic_accessors!(accessors)
      raise ArgumentError, "Model: #{name}#has_json_attributes_on, accessors must be a hash" unless accessors.is_a?(Hash)
      accessors = accessors.symbolize_keys
      accessors.each do |k,v|
        if columns.map(&:name).include?(k.to_s)
          raise ArgumentError, "Model: #{name}#has_json_attributes_on, accessor key:#{k} has already been defined as the model column"
        end

        begin
          v.assert_valid_keys(:type, :validates, :default)
        rescue Exception => e
          raise ArgumentError, "Model: #{name}#has_json_attributes_on, accessor key:#{k}, #{e.message}"
        end
      end
      return accessors
    end

    def build_json_attributes(data_column, data_column_sql_type, accessors)
      cattr_accessor :_json_attributes_on
      self._json_attributes_on ||= {}.symbolize_keys
      self._json_attributes_on[data_column] ||= {
        accessors: {},
        types: {},
        default_values: {},
        validations: {},
        delegators: [],
        data_column_sql_type: data_column_sql_type,
        value_type_class: VALUE_TYPE_CLASSES[data_column_sql_type].constantize,
        value_type_instance: nil
      }.symbolize_keys

      self._json_attributes_on[data_column][:accessors].merge!(accessors)

      accessors.each do |_accessor_attribute, options|
        self._json_attributes_on[data_column][:validations][_accessor_attribute] = options[:validates] if options[:validates]
        self._json_attributes_on[data_column][:default_values][_accessor_attribute] = options[:default]
        self._json_attributes_on[data_column][:types][_accessor_attribute] = options[:type] || 'String'
        self._json_attributes_on[data_column][:delegators] += [_accessor_attribute, "#{_accessor_attribute.to_s}=".to_sym]
      end

      # set attribute for this class
      self._json_attributes_on[data_column][:value_type_instance] = self._json_attributes_on[data_column][:value_type_class].new(self, data_column, self._json_attributes_on[data_column][:types])
      attribute data_column, self._json_attributes_on[data_column][:value_type_instance]

      # set the delegators
      def_delegators data_column, *self._json_attributes_on[data_column][:delegators]

      # set default values
      self._json_attributes_on[data_column][:default_values].each do |_accessor_attribute, _default_value|
        if _default_value.is_a?(Proc)
          default_value_for(_accessor_attribute, &_default_value)
        else
          default_value_for _accessor_attribute, _default_value
        end
      end

      # set validations
      self._json_attributes_on[data_column][:validations].each do |_accessor_attribute, _attribute_validations|
        validates _accessor_attribute, _attribute_validations
      end

    end
  end
end

ActiveRecord::Base.send(:include, HasJsonAttributesOn)
