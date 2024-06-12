# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationPresenter, feature_category: :software_composition_analysis do
  include Gitlab::Routing.url_helpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:presenter) { described_class.new(project, current_user: current_user) }

  describe '#to_h' do
    subject(:result) { presenter.to_h }

    it 'reports security_training_enabled' do
      allow(project).to receive(:security_training_available?).and_return(true)

      expect(result[:security_training_enabled]).to be_truthy
    end

    it 'includes a default value for continuous_vulnerability_scans_enabled' do
      expect(result[:continuous_vulnerability_scans_enabled]).to eq(false)
    end

    it 'includes a default value for container_scanning_for_registry_enabled' do
      expect(result[:container_scanning_for_registry_enabled]).to eq(false)
    end

    it 'includes a default value for pre_receive_secret_detection_enabled' do
      expect(result[:pre_receive_secret_detection_enabled]).to eq(false)
    end
  end

  describe '#to_html_data_attribute' do
    subject(:html_data) { presenter.to_html_data_attribute }

    before do
      stub_licensed_features(container_scanning_for_registry: true)
    end

    it 'includes container_scanning_for_registry feature information' do
      feature = Gitlab::Json.parse(html_data[:features]).find do |scan|
        scan['type'] == 'container_scanning_for_registry'
      end

      expect(feature['type']).to eq('container_scanning_for_registry')
      expect(feature['configured']).to eq(false)
      expect(feature['configuration_path']).to be_nil
      expect(feature['available']).to eq(true)
      expect(feature['can_enable_by_merge_request']).to eq(false)
      expect(feature['meta_info_path']).to be_nil
      expect(feature['security_features']).not_to be_empty
    end

    context 'when feature flag `container_scanning_for_registry` is disabled' do
      before do
        stub_feature_flags(container_scanning_for_registry_flag: false)
      end

      it 'does not includes container_scanning_for_registry feature information' do
        feature = Gitlab::Json.parse(html_data[:features]).find do |scan|
          scan['type'] == 'container_scanning_for_registry'
        end

        expect(feature).to be_nil
      end
    end
  end
end
