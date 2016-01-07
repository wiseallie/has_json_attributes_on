require 'active_record/connection_adapters/postgresql/oid/json'
require_relative 'json_type'
module HasJsonAttributesOn
  module Type
    class Json < ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Json
      include JsonType
    end
  end
end
