# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPoliciesFinder, feature_category: :security_policy_management do
  let!(:scan_result_policy) { build(:scan_result_policy, name: 'Contains security critical') }
  let!(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_result_policy: [scan_result_policy])
  end

  let(:policy) { scan_result_policy.merge({ type: 'scan_result_policy' }) }

  include_context 'with scan policies information'

  it_behaves_like 'scan policies finder'
end
