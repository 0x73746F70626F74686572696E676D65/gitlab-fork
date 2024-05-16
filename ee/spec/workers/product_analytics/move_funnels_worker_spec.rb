# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::MoveFunnelsWorker, feature_category: :product_analytics_data_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:previous_custom_dashboard_project) { create(:project, :repository) }
  let_it_be(:new_custom_dashboard_project) { create(:project, :repository) }

  before do
    allow_next_instance_of(ProductAnalytics::Settings) do |settings|
      allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@localhost:4567')
    end
  end

  before_all do
    previous_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
    new_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_changed.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
  end

  describe "perform" do
    context "when previous custom project doesn't exist" do
      it "calls configurator with 'created' funnel" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
            expect(url).to eq("http://test:test@localhost:4567/funnel-schemas")

            payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

            expect(payload).to match(
              a_hash_including(
                project_ids: ["gitlab_project_#{project.id}"],
                funnels: [a_hash_including(
                  state: "created"
                )]
              )
            )
          end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, nil, new_custom_dashboard_project.id)
      end
    end

    context "when next custom project doesn't exist" do
      it "calls configurator with 'deleted' funnel" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
          expect(url).to eq("http://test:test@localhost:4567/funnel-schemas")

          payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

          expect(payload).to match(
            a_hash_including(
              project_ids: ["gitlab_project_#{project.id}"],
              funnels: [a_hash_including(
                state: "deleted"
              )]
            )
          )
        end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, previous_custom_dashboard_project.id, nil)
      end
    end

    context "when both previous and next custom dashboard projects exist" do
      it "calls configurator with 'created' and 'deleted' funnels" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
          expect(url).to eq("http://test:test@localhost:4567/funnel-schemas")

          payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

          expect(payload).to match(
            a_hash_including(
              project_ids: ["gitlab_project_#{project.id}"],
              funnels: [a_hash_including(
                state: "deleted"
              ), a_hash_including(
                state: "created"
              )]
            )
          )
        end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, previous_custom_dashboard_project.id, new_custom_dashboard_project)
      end
    end
  end
end
