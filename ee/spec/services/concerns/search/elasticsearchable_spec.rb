# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elasticsearchable, feature_category: :global_search do
  let(:class_instance) { subject_class.new(current_user, params) }
  let_it_be(:current_user) { create(:user) }
  let(:params) { {} }
  let(:subject_class) do
    Class.new do
      attr_accessor :current_user, :params

      include Search::Elasticsearchable

      def initialize(current_user, params)
        @params = params
        @current_user = current_user
      end

      def elasticsearchable_scope
        nil
      end
    end
  end

  describe "#use_elasticsearch?" do
    it 'is false' do
      expect(class_instance).not_to be_use_elasticsearch
    end

    context 'when search_using_elasticsearch setting is enabled' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(true)
      end

      context 'when basic_search param is passed in' do
        let(:params) { { basic_search: true } }

        it 'is false' do
          expect(class_instance).not_to be_use_elasticsearch
        end
      end

      context 'when scope is epics' do
        let(:params) { { scope: 'epics' } }

        [true, false].each do |matcher|
          it 'is equal to advanced_epic_search?' do
            allow(class_instance).to receive(:advanced_epic_search?).and_return(matcher)

            expect(class_instance.use_elasticsearch?).to eq(matcher)
          end
        end
      end

      context 'when scope is notes' do
        let(:params) { { scope: 'notes' } }

        it 'is true' do
          expect(class_instance).to be_use_elasticsearch
        end
      end

      context 'when scope is users' do
        let(:params) { { scope: 'users' } }

        it 'returns true' do
          expect(class_instance).to be_use_elasticsearch
        end
      end
    end
  end

  describe "#advanced_epic_search?" do
    it 'is true when the scope is not epics' do
      expect(class_instance).to be_advanced_epic_search
    end

    context 'when scope is epics' do
      let(:params) { { scope: 'epics' } }

      context 'if backfill epics migration is finished' do
        before do
          allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:backfill_epics).and_return(true)
        end

        it 'is true' do
          expect(class_instance).to be_advanced_epic_search
        end
      end

      context 'if backfill epics migration is not finished' do
        before do
          allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:backfill_epics).and_return(false)
        end

        it 'is false' do
          expect(class_instance).not_to be_advanced_epic_search
        end
      end
    end
  end

  describe '#global_elasticsearchable_scope?' do
    it 'is false' do
      expect(class_instance).not_to be_global_elasticsearchable_scope
    end

    context 'when scope is users' do
      let(:params) { { scope: 'users' } }

      it 'is true' do
        expect(class_instance).to be_global_elasticsearchable_scope
      end
    end
  end
end
