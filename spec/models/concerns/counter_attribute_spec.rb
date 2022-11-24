# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CounterAttribute, :counter_attribute, :clean_gitlab_redis_shared_state do
  using RSpec::Parameterized::TableSyntax

  let(:project_statistics) { create(:project_statistics) }
  let(:model) { CounterAttributeModel.find(project_statistics.id) }

  it_behaves_like CounterAttribute, [:build_artifacts_size, :commit_count, :packages_size] do
    let(:model) { CounterAttributeModel.find(project_statistics.id) }
  end

  describe '#counter_attribute_enabled?' do
    it 'is true when counter attribute is defined' do
      expect(project_statistics.counter_attribute_enabled?(:build_artifacts_size))
        .to be_truthy
    end

    it 'is false when counter attribute is not defined' do
      expect(model.counter_attribute_enabled?(:nope)).to be_falsey
    end

    context 'with a conditional counter attribute' do
      [true, false].each do |enabled|
        context "where the condition evaluates to #{enabled}" do
          subject { model.counter_attribute_enabled?(:packages_size) }

          before do
            model.allow_package_size_counter = enabled
          end

          it { is_expected.to eq(enabled) }
        end
      end
    end
  end

  describe '#counter' do
    using RSpec::Parameterized::TableSyntax

    it 'returns the counter for the respective attribute' do
      expect(model.counter(:build_artifacts_size).send(:attribute)).to eq(:build_artifacts_size)
      expect(model.counter(:commit_count).send(:attribute)).to eq(:commit_count)
    end

    it 'returns the appropriate counter for the attribute' do
      expect(model.counter(:build_artifacts_size).class).to eq(Gitlab::Counters::BufferedCounter)
      expect(model.counter(:packages_size).class).to eq(Gitlab::Counters::BufferedCounter)
      expect(model.counter(:wiki_size).class).to eq(Gitlab::Counters::LegacyCounter)
    end

    context 'with a conditional counter attribute' do
      where(:enabled, :expected_counter_class) do
        [
          [true, Gitlab::Counters::BufferedCounter],
          [false, Gitlab::Counters::LegacyCounter]
        ]
      end

      with_them do
        before do
          model.allow_package_size_counter = enabled
        end

        it 'returns the appropriate counter based on the condition' do
          expect(model.counter(:packages_size).class).to eq(expected_counter_class)
        end
      end
    end

    it 'raises error for unknown attribute' do
      expect { model.counter(:unknown) }.to raise_error(ArgumentError, 'attribute "unknown" does not exist')
    end
  end
end
