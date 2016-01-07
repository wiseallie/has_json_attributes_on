require 'active_record/connection_adapters/postgresql/oid/jsonb'
require_relative 'json_type'
module HasJsonAttributesOn
  module Type
    class Jsonb < ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Jsonb
      include JsonType
    end
  end
end
