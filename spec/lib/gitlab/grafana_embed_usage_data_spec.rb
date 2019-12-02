# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::GrafanaEmbedUsageData do
  describe '#issue_count', :use_clean_rails_memory_store_caching do
    subject do
      described_class.issue_count
    end

    let(:project) { create(:project) }
    let(:description_with_embed) { "Some comment\n\nhttps://grafana.example.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }
    let(:description_with_unintegrated_embed) { "Some comment\n\nhttps://grafana.exp.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }

    shared_examples "zero count" do
      it "does not count the issue" do
        expect(subject).to eq(0)
      end
    end

    context 'with project grafana integration enabled' do
      before do
        create(:grafana_integration, project: project)
      end

      context 'with valid and invalid embeds' do
        before do
          create(:issue, project: project, description: description_with_embed)
          create(:issue, project: project, description: description_with_embed)
          create(:issue, project: project, description: description_with_unintegrated_embed)
          create(:issue, project: project, description: nil)
          create(:issue, project: project, description: '')
          create(:issue, project: project)
        end

        it 'counts only the issues with embeds' do
          expect(subject).to eq(2)
        end
      end
    end

    context 'with project grafana integration disabled' do
      before do
        create(:grafana_integration, project: project, enabled: false)
      end

      context 'with one issue having a grafana link in the description and one without' do
        before do
          create(:issue, project: project, description: description_with_embed)
          create(:issue, project: project)
        end

        it_behaves_like('zero count')
      end
    end

    context 'with an un-integrated project' do
      context 'with one issue having a grafana link in the description and one without' do
        before do
          create(:issue, project: project, description: description_with_embed)
          create(:issue, project: project)
        end

        it_behaves_like('zero count')
      end
    end
  end
end
