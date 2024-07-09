# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Type, feature_category: :team_planning do
  describe '#widgets' do
    let_it_be(:group) { build_stubbed(:group) }
    let_it_be(:project) { build_stubbed(:project, group: group) }
    let_it_be_with_refind(:work_item_type) { create(:work_item_type, :default) }
    let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
    let(:disabled_features) { [] }

    before_all do
      # All possible default work item types already exist on the DB. So we find the first one, remove all existing
      # widgets and then add all existing ones. This type now has all possible widgets just for testing.
      WorkItems::WidgetDefinition.where(work_item_type: work_item_type).delete_all
      WorkItems::WidgetDefinition.widget_types.each_key do |type|
        create(:widget_definition, :default, work_item_type: work_item_type, name: type.to_s, widget_type: type)
      end
    end

    shared_examples 'work_item_type returning only licensed widgets' do
      let(:feature) { feature_widget.first }
      let(:widget_classes) { feature_widget.last }

      subject(:returned_widgets) { work_item_type.widgets(parent) }

      context 'when feature is available' do
        it 'returns the associated licensesd widget' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).to include(widget)
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).not_to include(widget)
          end
        end
      end
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      before do
        stub_licensed_features(**feature_hash)
      end

      context 'when parent is a group' do
        let(:parent) { group }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end

      context 'when parent is a project' do
        let(:parent) { project }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end
    end
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end
end
