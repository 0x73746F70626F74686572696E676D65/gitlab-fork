# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PlayBridgeService, '#execute', feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:downstream_project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: [project, downstream_project]) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be_with_reload(:job) { create(:ci_bridge, :playable, pipeline: pipeline, downstream: downstream_project) }

  subject { described_class.new(project, user).execute(job) }

  it_behaves_like 'authorizing CI jobs'
end
