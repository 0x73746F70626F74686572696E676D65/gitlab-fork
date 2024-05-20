# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MutationType do
  describe 'deprecated mutations' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name, :reason, :milestone) do
      'ApiFuzzingCiConfigurationCreate' | 'The configuration snippet is now generated client-side' | '15.1'
    end

    with_them do
      let(:field) { get_field(field_name) }
      let(:deprecation_reason) { "#{reason}. Deprecated in #{milestone}." }

      it { expect(field).not_to be_present }
    end
  end

  def get_field(name)
    described_class.fields[GraphqlHelpers.fieldnamerize(name)]
  end

  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end
end
