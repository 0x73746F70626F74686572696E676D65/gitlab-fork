# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Search results for settings", :js, feature_category: :global_search, type: :feature do
  before do
    stub_licensed_features(
      issuable_default_templates: true,
      target_branch_rules: true,
      push_rules: true,
      merge_request_approvers: true,
      protected_environments: true,
      auto_rollback: true,
      ci_project_subscriptions: true,
      status_page: true
    )
  end

  it_behaves_like 'all sections exist and have correct anchor links'
end
