# frozen_string_literal: true

require "spec_helper"
require_migration!

RSpec.describe UpdateCiMaxTotalYamlSizeBytesDefaultValue, feature_category: :pipeline_composition do
  let(:application_setting) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'application_settings'
    end
  end

  describe '#up' do
    it "#up" do
      application_setting.create!
      setting = application_setting.first

      # default value
      expect(setting.ci_max_total_yaml_size_bytes).to eq(157286400)

      # when max_yaml_size_bytes was increased by the self-hosted admin
      setting.update!(max_yaml_size_bytes: 2.megabytes)

      migrate!

      setting = application_setting.first

      ci_max_includes = setting.ci_max_includes
      max_yaml_size_bytes = setting.max_yaml_size_bytes

      new_limit = max_yaml_size_bytes * ci_max_includes

      expect(setting.ci_max_total_yaml_size_bytes).to eq(new_limit)
    end
  end
end
