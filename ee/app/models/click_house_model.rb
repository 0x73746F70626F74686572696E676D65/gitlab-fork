# frozen_string_literal: true

class ClickHouseModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  class << self
    attr_accessor :table_name
  end
end
