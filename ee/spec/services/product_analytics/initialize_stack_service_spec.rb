# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::InitializeStackService, :clean_gitlab_redis_shared_state,
  feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

  before do
    project.add_maintainer(user)
    stub_feature_flags(product_analytics_billing_override: false)
  end

  shared_examples 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued' do
    it 'does not enqueue a job' do
      expect(::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker).not_to receive(:perform_async)

      subject
    end
  end

  shared_examples '::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued' do
    it 'enqueues a job' do
      expect(::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker)
        .to receive(:perform_async).with(project.id)
      expect(subject.message).to eq('Product analytics initialization started')
    end
  end

  describe '#lock!' do
    subject { described_class.new(container: project, current_user: user).lock! }

    it 'sets the redis key' do
      expect { subject }
        .to change {
          described_class.new(container: project, current_user: user).send(:locked?)
        }.from(false).to(true)
    end
  end

  describe '#unlock!' do
    subject { described_class.new(container: project, current_user: user).unlock! }

    it 'deletes the redis key' do
      subject

      expect(described_class.new(container: project, current_user: user).send(:locked?)).to eq false
    end
  end

  describe '#execute' do
    subject { described_class.new(container: project, current_user: user).execute }

    before do
      stub_licensed_features(product_analytics: true)
      stub_ee_application_setting(product_analytics_enabled: true)
      stub_feature_flags(product_analytics_billing: false)
    end

    context 'when snowplow support is enabled' do
      it 'enqueues a job' do
        expect(::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker)
          .to receive(:perform_async).with(project.id)

        described_class.new(container: project, current_user: user).execute
      end

      it 'locks the job' do
        subject

        expect(described_class.new(container: project, current_user: user).send(:locked?)).to eq true
      end

      context 'when project is already initialized for product analytics' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: '123')
        end

        it 'returns an error response' do
          expect(subject).to be_error
          expect(subject.message).to eq('Product analytics initialization is already complete')
        end
      end
    end

    context 'when product analytics is disabled per project' do
      before do
        allow(project).to receive(:product_analytics_enabled?).and_return(false)
      end

      it_behaves_like 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'

      it 'returns an error' do
        expect(subject.message).to eq "Product analytics is disabled for this project"
      end
    end

    context 'when product analytics is disabled at instance level' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(false)
      end

      it_behaves_like 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'

      it 'returns an error' do
        expect(subject.message).to eq "Product analytics is disabled"
      end
    end

    context 'when user does not have permission to initialize product analytics' do
      before do
        project.add_guest(user)
      end

      it_behaves_like 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'
    end

    context 'when enable_product_analytics application setting is false' do
      before do
        stub_ee_application_setting(product_analytics_enabled: false)
      end

      it_behaves_like 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'
    end

    context 'when the product_analytics_billing flag is disabled' do
      before do
        project.project_setting.update!(product_analytics_instrumentation_key: nil)
      end

      it_behaves_like '::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'
    end

    context 'when the product_analytics_billing flag is enabled' do
      before do
        project.project_setting.update!(product_analytics_instrumentation_key: nil)
        stub_application_setting(
          product_analytics_data_collector_host: 'https://gl-product-analytics.com:4567'
        )
        stub_feature_flags(product_analytics_billing: project.root_ancestor)
      end

      context 'when product_analytics add on is not purchased' do
        it_behaves_like 'no ::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'

        it 'returns an error' do
          expect(subject.message).to eq "Product analytics is disabled for this project"
        end

        context 'when user brings their own cluster' do
          before do
            stub_application_setting(product_analytics_data_collector_host: 'https://my-data-collector.customer-xyz.com')
          end

          it_behaves_like '::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'
        end
      end

      context 'when product_analytics add on has been purchased' do
        before do
          create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on)
        end

        it_behaves_like '::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker job is enqueued'
      end
    end
  end
end
