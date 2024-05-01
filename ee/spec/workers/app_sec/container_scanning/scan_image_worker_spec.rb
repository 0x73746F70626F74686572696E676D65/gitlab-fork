# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::ContainerScanning::ScanImageWorker, feature_category: :software_composition_analysis do
  let_it_be(:project) { create(:project, :repository, :container_scanning_for_registry_enabled) }

  let(:worker) { described_class.new }
  let(:project_id) { project.id }
  let(:user_id) { project.owner.id }
  let(:image) { "registry.gitlab.com/gitlab-org/security-products/dast/webgoat-8.0@test:latest" }
  let(:data) { { project_id: project_id, user_id: user_id, image: image } }
  let(:image_pushed_event) { ContainerRegistry::ImagePushedEvent.new(data: data) }

  before do
    image_pushed_event.project = project
  end

  describe '#handle_event' do
    it_behaves_like 'subscribes to event' do
      let(:event) { image_pushed_event }
    end

    it 'calls ScanImageService' do
      expect_next_instance_of(
        AppSec::ContainerScanning::ScanImageService,
        image: image, project_id: project_id, user_id: user_id
      ) do |service|
        expect(service).to receive(:execute)
      end

      consume_event(subscriber: described_class, event: image_pushed_event)
    end
  end

  describe '.dispatch?' do
    context 'when image ends with :latest' do
      it 'returns true' do
        expect(described_class.dispatch?(image_pushed_event)).to eq(true)
      end
    end

    context 'when image does not end with :latest' do
      it 'returns false' do
        image_pushed_event.data[:image] = 'some_image:other_tag'
        expect(described_class.dispatch?(image_pushed_event)).to eq(false)
      end
    end

    context 'when security_setting is nil' do
      before do
        allow(image_pushed_event.project).to receive(:security_setting).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.dispatch?(image_pushed_event)).to eq(false)
      end
    end

    context 'when project repository is empty' do
      before do
        allow(image_pushed_event.project.repository).to receive(:empty?).and_return(true)
      end

      it 'returns false' do
        expect(described_class.dispatch?(image_pushed_event)).to eq(false)
      end
    end
  end
end
