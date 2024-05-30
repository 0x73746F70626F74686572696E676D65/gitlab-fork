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

    context 'when the cube_api_key is set' do
      before do
        project.project_setting.update!(cube_api_key: "thisisasecretkey")
      end

      it 'adds an audit event', :aggregate_failures do
        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details)
          .to include({ change: :encrypted_cube_api_key })

        # 'from' and 'to' should be nil, as their value is encrypted
        # and we should not expose it in the audit logs
        expect(AuditEvent.last.details[:from]).to be_nil
        expect(AuditEvent.last.details[:to]).to be_nil
      end
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

    context 'when the snowplow configurator connection string is set' do
      before do
        project.project_setting.update!(product_analytics_configurator_connection_string: "http://example.com")
      end

      it 'adds an audit event', :aggregate_failures do
        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details)
          .to include({ change: :encrypted_product_analytics_configurator_connection_string })

        # 'from' and 'to' should be nil, as their value is encrypted
        # and we should not expose it in the audit logs
        expect(AuditEvent.last.details[:from]).to be_nil
        expect(AuditEvent.last.details[:to]).to be_nil
      end
    end

    context 'when the product_analytics_data_collector_host is set' do
      before do
        project.project_setting.update!(product_analytics_data_collector_host: "http://example2.com")
      end

      it 'adds an audit event' do
        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details)
          .to include({ change: :product_analytics_data_collector_host, from: nil, to: "http://example2.com" })
      end
    end

    context 'when the cube_api_base_url is set' do
      before do
        project.project_setting.update!(cube_api_base_url: "http://example3.com")
      end

      it 'adds an audit event' do
        expect { auditor.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details)
          .to include({ change: :cube_api_base_url, from: nil, to: "http://example3.com" })
      end
    end
  end
end
