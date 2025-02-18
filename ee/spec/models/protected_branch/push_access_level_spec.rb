# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranch::PushAccessLevel, feature_category: :source_code_management do
  it_behaves_like 'ee protected ref access', :protected_branch
end
