require 'rails'
require_relative 'has_json_attributes_on/type/json'
require_relative 'has_json_attributes_on/type/jsonb'

module HasJsonAttributesOn
  extend ActiveSupport::Concern

  VALUE_TYPE_CLASSES = {
    'json' => HasJsonAttributesOn::Type::Json,
    'jsonb' => HasJsonAttributesOn::Type::Jsonb
  }

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

      data_column_sql_type = columns.detect{|x| x.name.to_s == data_column.to_s}.sql_type.to_s
      unless data_column_sql_type.in?(VALUE_TYPE_CLASSES.keys)
        raise ArgumentError,  "Model: #{name}#has_json_attributes_on, data_column: #{data_column} is of sql type: #{data_column_sql_type}, supported types are:#{VALUE_TYPE_CLASSES.keys}"
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
        value_type_class: VALUE_TYPE_CLASSES[data_column_sql_type.to_s].constantize,
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
          # pass the context to self in the proc
          default_value_for(_accessor_attribute,  &_default_value)
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
