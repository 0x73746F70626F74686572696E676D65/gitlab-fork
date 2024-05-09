# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AgentVersionAttachment, feature_category: :mlops do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:version) }
    it { is_expected.to belong_to(:file) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:file) }
  end
end
