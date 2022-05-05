# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InstanceClusterablePresenter do
  include Gitlab::Routing.url_helpers

  let(:presenter) { described_class.new(instance) }
  let(:cluster) { create(:cluster, :provided_by_gcp, :instance) }
  let(:instance) { cluster.instance }

  describe '#connect_path' do
    subject { described_class.new(instance).connect_path }

    it { is_expected.to eq(connect_admin_clusters_path) }
  end

  describe '#clear_cluster_cache_path' do
    subject { presenter.clear_cluster_cache_path(cluster) }

    it { is_expected.to eq(clear_cache_admin_cluster_path(cluster)) }
  end

  describe '#metrics_dashboard_path' do
    subject { presenter.metrics_dashboard_path(cluster) }

    it { is_expected.to eq(metrics_dashboard_admin_cluster_path(cluster)) }
  end

  describe '#learn_more_link' do
    subject { presenter.learn_more_link }

    it { is_expected.to include('user/instance/clusters/index') }
  end
end
