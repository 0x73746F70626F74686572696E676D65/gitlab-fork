# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::FunnelStep, feature_category: :product_analytics_data_management do
  let(:funnel) do
    ::ProductAnalytics::Funnel.new(
      name: 'test',
      project: create(:project, :repository),
      seconds_to_convert: 300,
      config_path: 'nothing',
      config_project: create(:project, :repository)
    )
  end

  let(:funnel_step) { described_class.new(name: 'test', target: '/page1.html', action: 'pageview', funnel: funnel) }

  describe '#initialize' do
    it 'has a name' do
      expect(funnel_step.name).to eq('test')
    end

    it 'has a target' do
      expect(funnel_step.target).to eq('/page1.html')
    end

    it 'has an action' do
      expect(funnel_step.action).to eq('pageview')
    end

    context 'when action is not a valid type' do
      let(:funnel_step) do
        described_class.new(name: 'test', target: '/page1.html', action: 'invalid', funnel: funnel).valid?
      end

      it 'raises an error' do
        expect { funnel_step }.to raise_error(ActiveModel::StrictValidationFailed)
      end
    end
  end

  describe '#to_h' do
    subject { funnel_step.to_h }

    let(:expected) do
      {
        name: 'test',
        target: '/page1.html',
        action: 'pageview'
      }
    end

    it { is_expected.to eq expected }
  end

  describe '#step_definition' do
    subject { funnel_step.step_definition }

    context 'when snowplow' do
      it { is_expected.to eq("page_urlpath = '/page1.html'") }
    end
  end
end
