# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedTag::CreateAccessLevel, feature_category: :source_code_management do
  it_behaves_like 'ee protected ref access', :protected_tag
  it_behaves_like 'protected ref access configured for users', :protected_tag
  it_behaves_like 'protected ref access configured for groups', :protected_tag
end
