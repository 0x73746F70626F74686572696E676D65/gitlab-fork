# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SourcePackage, type: :model, feature_category: :dependency_management do
  describe 'enums' do
    it_behaves_like 'purl_types enum'
  end

  describe '.by_purl_type_and_name scope' do
    let_it_be(:matching_sbom_component) { create(:sbom_source_package, purl_type: 'apk', name: 'component-1') }
    let_it_be(:non_matching_sbom_component) { create(:sbom_source_package, purl_type: 'deb', name: 'component-2') }

    subject { described_class.by_purl_type_and_name('apk', 'component-1') }

    it { is_expected.to eq([matching_sbom_component]) }
  end
end
