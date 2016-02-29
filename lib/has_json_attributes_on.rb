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
    # extend Forwardable
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

    def table_and_data_column_exist?(data_column, _table_name = self.table_name)
      # check if we have database connection and the table columns
      begin
        raise "database table: #{self.table_name} does not exist" unless  ActiveRecord::Base.connection.table_exists? _table_name.to_s
        # try and access columns
        raise "column: #{data_column} of database table #{self.table_name} does not exist"  unless columns.map(&:name).include?(data_column.to_s)
        return true
      rescue Exception => e
        puts "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, #{e.message}, skipping..."
        puts "\n\n\nPLEASE RUN ALL MIGRATIONS FIRST BEFORE RUNNING ANYTHING ELSE!!!\n\n\n"
        return false
      end
    end

    def has_json_attributes_on(data_column = :data, accessors = {})
      return unless table_and_data_column_exist?(data_column, self.table_name)
      validated_data_column, data_column_sql_type = validate_json_attributes_data_column!(data_column)
      validated_accessors = validate_dynamic_accessors!(accessors)
      build_json_attributes(validated_data_column, data_column_sql_type, validated_accessors)
    end

    private

    def validate_json_attributes_data_column!(data_column)
      data_column = data_column.to_sym
      begin
        unless columns.map(&:name).include?(data_column.to_s)
          raise ArgumentError,  "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, data_column: #{data_column} does not exist as a column in database"
        end

        data_column_sql_type = columns.detect{|x| x.name.to_s == data_column.to_s}.sql_type.to_s
        unless data_column_sql_type.in?(VALUE_TYPE_CLASSES.keys)
          raise ArgumentError,  "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, data_column: #{data_column} is of sql type: #{data_column_sql_type}, supported types are:#{VALUE_TYPE_CLASSES.keys}"
        end
      rescue Exception => e
        puts e
        return [data_column, 'json']
      end
      return [data_column, data_column_sql_type]
    end


    def validate_dynamic_accessors!(accessors)
      raise ArgumentError, "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, accessors must be a hash" unless accessors.is_a?(Hash)
      accessors = accessors.symbolize_keys
      accessors.each do |k,v|
        if columns.map(&:name).include?(k.to_s)
          raise ArgumentError, "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, accessor key:#{k} has already been defined as the model column"
        end

        begin
          v.assert_valid_keys(:type, :validates, :default)
        rescue Exception => e
          raise ArgumentError, "HasJsonAttributesOn => Model: #{name}#has_json_attributes_on, accessor key:#{k}, #{e.message}"
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
        data_column_sql_type: data_column_sql_type,
        value_type_class: VALUE_TYPE_CLASSES[data_column_sql_type.to_s],
        serializer_klazz: nil
      }.symbolize_keys

      self._json_attributes_on[data_column][:accessors].merge!(accessors)

      accessors.each do |_accessor_attribute, options|
        self._json_attributes_on[data_column][:validations][_accessor_attribute] = options[:validates] if options[:validates]
        self._json_attributes_on[data_column][:default_values][_accessor_attribute] = options[:default]
        self._json_attributes_on[data_column][:types][_accessor_attribute] = options[:type] || 'String'
      end

      self._json_attributes_on[data_column][:serializer_klazz]  =  self._json_attributes_on[data_column][:value_type_class].build_serializer(self, data_column, self._json_attributes_on[data_column][:types])

      store data_column,
      accessors:  accessors.keys,
      coder: self._json_attributes_on[data_column][:serializer_klazz]


      define_method data_column.to_sym do
        column_value = self[data_column.to_sym]
        unless self._json_attributes_on[data_column][:serializer_klazz].is_my_type?(column_value)
          column_value = self._json_attributes_on[data_column][:serializer_klazz].virtus_model.new(column_value)
        end
        column_value
      end

      define_method "#{data_column.to_s}=" do |value|
        unless self._json_attributes_on[data_column][:serializer_klazz].is_my_type?(value)
          value = self._json_attributes_on[data_column][:serializer_klazz].virtus_model.new(value)
        end
        raw_write_attribute(data_column, value.to_hash)
        send("#{data_column.to_s}_will_change!")
      end

      accessors.keys.each do |_accessor_attribute|
        define_method _accessor_attribute.to_sym do
          column_value = send(data_column)
          column_value.send(_accessor_attribute)
        end

        define_method "#{_accessor_attribute.to_s}=" do |value|
          column_value = send(data_column)
          column_value.send("#{_accessor_attribute.to_s}=", value)
          send("#{data_column.to_s}=", column_value)
          value
        end
      end

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

      self.after_initialize :build_json_attributes
    end
  end

  def build_json_attributes
    # ensure that we can call the method
    self._json_attributes_on.each_pair do |data_column, options|
      send(data_column);
    end
    return true
  end

end

ActiveRecord::Base.send(:include, HasJsonAttributesOn)
