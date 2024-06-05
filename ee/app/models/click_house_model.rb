# frozen_string_literal: true

class ClickHouseModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  class << self
    attr_accessor :table_name
  end

  def store
    return false unless valid?

    ::ClickHouse::WriteBuffer.add(self.class.table_name, to_clickhouse_csv_row)
  end

  def to_clickhouse_csv_row
    raise NoMethodError # must be overloaded in descendants
  end
end
