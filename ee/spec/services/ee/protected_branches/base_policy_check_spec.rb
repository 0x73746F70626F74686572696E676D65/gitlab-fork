# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::ProtectedBranches::BasePolicyCheck, '#violated?', feature_category: :security_policy_management do
  it 'raises' do
    expect { described_class.new(nil, nil).violated? }.to raise_error(NotImplementedError)
  end
end
