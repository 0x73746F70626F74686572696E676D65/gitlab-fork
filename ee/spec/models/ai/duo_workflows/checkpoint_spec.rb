# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Checkpoint, feature_category: :duo_workflow do
  it { is_expected.to validate_presence_of(:thread_ts) }
  it { is_expected.to validate_presence_of(:checkpoint) }
  it { is_expected.to validate_presence_of(:metadata) }
end
