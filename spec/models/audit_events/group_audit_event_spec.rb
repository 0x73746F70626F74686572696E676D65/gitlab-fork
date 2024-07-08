# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::GroupAuditEvent, feature_category: :audit_events do
  it_behaves_like 'includes ::AuditEvents::CommonModel concern' do
    let_it_be(:audit_event_symbol) { :audit_events_group_audit_event }
    let_it_be(:audit_event_class) { described_class }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group_id) }
  end

  describe '.by_group' do
    let_it_be(:group_audit_event_1) { create(:audit_events_group_audit_event) }
    let_it_be(:group_audit_event_2) { create(:audit_events_group_audit_event) }

    subject(:event) { described_class.by_group(group_audit_event_1.group_id) }

    it 'returns the correct audit event' do
      expect(event).to contain_exactly(group_audit_event_1)
    end
  end

  describe '#root_group_entity' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }

    context 'when root_group_entity_id is set' do
      subject(:event) { described_class.new(root_group_entity_id: root_group.id) }

      it "return root_group_entity through root_group_entity_id" do
        expect(event.root_group_entity).to eq(root_group)
      end
    end

    context "when group is nil" do
      subject(:event) { described_class.new(group: nil) }

      it "return nil" do
        expect(event.root_group_entity).to eq(nil)
      end
    end

    subject(:event) { described_class.new(group: group) }

    it "return root_group and set root_group_entity_id" do
      expect(event.root_group_entity).to eq(root_group)
      expect(event.root_group_entity_id).to eq(root_group.id)
    end
  end
end
