# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Build::Rules::Rule::Clause::Exists do
  describe 'satisfied_by?' do
    let(:project) { create(:project, :custom_repo, files: files) }
    let(:pipeline) { build(:ci_pipeline, project: project, sha: project.repository.head_commit.sha) }
    subject { described_class.new(globs) }

    it_behaves_like 'a glob matching rule'
  end
end
