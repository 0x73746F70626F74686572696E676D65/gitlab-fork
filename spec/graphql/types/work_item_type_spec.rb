# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WorkItem'] do
  specify { expect(described_class.graphql_name).to eq('WorkItem') }

  specify { expect(described_class).to require_graphql_authorizations(:read_work_item) }

  specify { expect(described_class).to expose_permissions_using(Types::PermissionTypes::WorkItem) }

  it 'has specific fields' do
    fields = %i[description description_html id iid lock_version state title title_html userPermissions work_item_type]

    fields.each do |field_name|
      expect(described_class).to have_graphql_fields(*fields)
    end
  end
end
