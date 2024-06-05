# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RolledupDates::BulkUpdateHandler, feature_category: :team_planning do
  let_it_be(:service_class) { ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService }
  let_it_be(:group) { create(:group) }
  let_it_be(:work_items) { create_list(:work_item, 2, namespace: group) }

  let(:event) do
    instance_double(
      Milestones::MilestoneUpdatedEvent,
      data: {
        root_namespace_id: group.id,
        work_item_ids: work_items.map(&:id)
      })
  end

  describe ".can_handle?" do
    context "when the feature flag is disabled" do
      before do
        stub_feature_flags(work_items_rolledup_dates: false)
      end

      it "returns false" do
        expect(described_class.can_handle?(event)).to eq(false)
      end
    end

    context "when the feature flag is enabled" do
      before do
        stub_feature_flags(work_items_rolledup_dates: group)
      end

      context "and no trigger attributes are changed" do
        it "returns false" do
          expect(described_class.can_handle?(event)).to eq(false)
        end
      end

      context "and trigger attributes have changed" do
        it "returns true" do
          described_class::UPDATE_TRIGGER_ATTRIBUTES.each do |attribute|
            event.data[:updated_attributes] = [attribute]

            expect(described_class.can_handle?(event)).to eq(true)
          end

          expect(described_class.can_handle?(event)).to eq(true)
        end
      end
    end
  end

  describe "#handle_event" do
    subject(:handler) { described_class.new }

    it "calls the service with the given work_items" do
      expect_next_instance_of(service_class, work_items) do |service|
        expect(service).to receive(:execute)
      end

      handler.handle_event(event)
    end
  end
end
