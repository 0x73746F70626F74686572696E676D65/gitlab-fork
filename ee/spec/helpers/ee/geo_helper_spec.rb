# frozen_string_literal: true
require 'spec_helper'

RSpec.describe EE::GeoHelper, feature_category: :geo_replication do
  describe '.current_node_human_status' do
    where(:primary, :secondary, :result) do
      [
        [true, false, s_('Geo|primary')],
        [false, true, s_('Geo|secondary')],
        [false, false, s_('Geo|misconfigured')]
      ]
    end

    with_them do
      it 'returns correct results' do
        allow(::Gitlab::Geo).to receive(:primary?).and_return(primary)
        allow(::Gitlab::Geo).to receive(:secondary?).and_return(secondary)

        expect(described_class.current_node_human_status).to eq result
      end
    end
  end

  describe '#replicable_types' do
    subject(:names) { helper.replicable_types.map { |t| t[:name_plural] } }

    it 'includes replicator types' do
      expected_names = helper.enabled_replicator_classes.map { |c| c.replicable_name_plural }

      expect(names).to include(*expected_names)
    end

    it 'includes replicator data types' do
      data_types = helper.replicable_types.map { |t| t[:data_type] }
      expected_data_types = helper.enabled_replicator_classes.map { |c| c.data_type }

      expect(data_types).to include(*expected_data_types)
    end

    it 'includes replicator data type titles' do
      data_type_titles = helper.replicable_types.map { |t| t[:data_type_title] }
      expected_data_type_titles = helper.enabled_replicator_classes.map { |c| c.data_type_title }

      expect(data_type_titles).to include(*expected_data_type_titles)
    end

    it 'includes replicator data type sort order' do
      helper.replicable_types.each { |t| expect(t[:data_type_sort_order]).to be_present }

      expect(helper.replicable_types.size >= helper.enabled_replicator_classes.size).to be_truthy
    end
  end

  describe '#geo_filter_nav_options' do
    let(:replicable_controller) { 'admin/geo/replicables' }
    let(:replicable_name) { 'projects' }
    let(:expected_nav_options) do
      [
        { value: "", text: "All projects", href: "/admin/geo/replication/projects" },
        { value: "pending", text: "In progress", href: "/admin/geo/replication/projects?sync_status=pending" },
        { value: "failed", text: "Failed", href: "/admin/geo/replication/projects?sync_status=failed" },
        { value: "synced", text: "Synced", href: "/admin/geo/replication/projects?sync_status=synced" }
      ]
    end

    subject(:geo_filter_nav_options) { helper.geo_filter_nav_options(replicable_controller, replicable_name) }

    it 'returns correct urls' do
      expect(geo_filter_nav_options).to eq(expected_nav_options)
    end
  end

  describe '#format_file_size_for_checksum' do
    context 'when file size is of even length' do
      it 'returns same file size string' do
        expect(helper.format_file_size_for_checksum("12")).to eq("12")
      end
    end

    context 'when file size is of odd length' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("123")).to eq("0123")
      end
    end

    context 'when file size is 0' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("0")).to eq("00")
      end
    end
  end
end
