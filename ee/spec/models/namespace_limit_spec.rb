# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NamespaceLimit do
  let(:namespace_limit) { build(:namespace_limit) }
  let(:usage_ratio) { 0.5 }
  let(:namespace_storage_limit_enabled) { true }

  subject { namespace_limit }

  before do
    stub_feature_flags(namespace_storage_limit: namespace_storage_limit_enabled)

    [Namespaces::Storage::RootSize, Namespaces::Storage::RootExcessSize].each do |class_name|
      allow_next_instance_of(class_name, namespace_limit.namespace) do |root_storage|
        allow(root_storage).to receive(:usage_ratio).and_return(usage_ratio)
      end
    end
  end

  it { is_expected.to belong_to(:namespace) }

  describe '#eligible_additional_purchased_storage_size' do
    subject { namespace_limit.eligible_additional_purchased_storage_size }

    before do
      allow(namespace_limit).to receive(:additional_purchased_storage_size)
        .and_return(10)
    end

    context 'with expired_storage_check ff enabled' do
      before do
        stub_feature_flags(expired_storage_check: true)
      end

      context 'with expired storage' do
        before do
          allow(namespace_limit).to receive(:additional_purchased_storage_ends_on)
            .and_return(Date.yesterday)
        end

        it { is_expected.to eq(0) }
      end

      context 'with valid storage' do
        before do
          allow(namespace_limit).to receive(:additional_purchased_storage_ends_on)
            .and_return(Date.tomorrow)
        end

        it { is_expected.to eq(10) }
      end
    end

    context 'with expired_storage_check ff disabled' do
      before do
        stub_feature_flags(expired_storage_check: false)
      end

      context 'with expired storage' do
        before do
          allow(namespace_limit).to receive(:additional_purchased_storage_ends_on)
            .and_return(Date.yesterday)
        end

        it { is_expected.to eq(10) }
      end

      context 'with valid storage' do
        before do
          allow(namespace_limit).to receive(:additional_purchased_storage_ends_on)
            .and_return(Date.tomorrow)
        end

        it { is_expected.to eq(10) }
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }

    context 'with namespace_is_root_namespace' do
      let(:namespace_limit) { build(:namespace_limit, namespace: namespace) }

      context 'when associated namespace is root' do
        let(:namespace) { build(:group, parent: nil) }

        it { is_expected.to be_valid }
      end

      context 'when associated namespace is not root' do
        let(:namespace) { build(:group, :nested) }

        it 'is invalid' do
          expect(subject).to be_invalid
          expect(subject.errors[:namespace]).to include('must be a root namespace')
        end
      end
    end
  end
end
