# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Audit::ProjectAnalyticsChangesAuditor, feature_category: :product_analytics_data_management do
  describe 'auditing project analytics changes' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:auditor) { described_class.new(user, project.project_setting, project) }

    before do
      project.reload
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    context 'when the pointer project is changed' do
      before do
        project.build_analytics_dashboards_pointer
        project.analytics_dashboards_pointer.update!(target_project_id: Project.last.id)
      end

      it 'adds an audit event', :aggregate_failures do
        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details)
          .to include({ change: :analytics_dashboards_pointer, from: nil, to: Project.last.id })
      end
    end

    context 'when the settings are defined' do
      before do
        project.project_setting.update!(
          product_analytics_configurator_connection_string: 'https://gl-product-analytics-configurator.gl.com:4567',
          product_analytics_data_collector_host: 'http://test.net',
          cube_api_base_url: 'https://test.com:3000',
          cube_api_key: 'helloworld'
        )
      end

      it 'adds 4 audit events' do
        expect { auditor.execute }.to change { AuditEvent.count }.by(4)
      end

      it 'has the correct audit event types' do
        auditor.execute
        details = AuditEvent.last(4).map { |ae| ae.details[:change] }

        expect(details).to include(:product_analytics_configurator_connection_string,
          :product_analytics_data_collector_host,
          :cube_api_base_url,
          :cube_api_key)
      end
    end
  end
end
