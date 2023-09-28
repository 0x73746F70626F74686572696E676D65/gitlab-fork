# frozen_string_literal: true

require 'fast_spec_helper'
require 'support/helpers/saas_test_helper'

RSpec.describe Gitlab::Saas, feature_category: :shared do
  include SaasTestHelper

  describe '.canary_toggle_com_url' do
    subject { described_class.canary_toggle_com_url }

    it { is_expected.to eq(get_next_url) }
  end
end
