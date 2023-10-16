# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BitbucketImport::ImportLfsObjectWorker, feature_category: :importers do
  subject(:worker) { described_class.new }

  it_behaves_like Gitlab::BitbucketImport::ObjectImporter do
    before do
      # Stub the LfsDownloadObject for these tests so it can be passed an empty Hash
      allow(LfsDownloadObject).to receive(:new)
    end
  end
end
