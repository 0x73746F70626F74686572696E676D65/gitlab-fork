# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::Blob::FileType, feature_category: :global_search do
  it { expect(described_class.graphql_name).to eq('SearchBlobFileType') }

  it 'has all the required fields' do
    expect(described_class).to have_graphql_fields(:path, :file_url, :blame_url, :match_count_total, :match_count,
      :chunks, :project_path)
  end
end
