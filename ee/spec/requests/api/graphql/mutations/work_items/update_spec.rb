# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:reporter) { create(:user).tap { |user| group.add_reporter(user) } }
  let_it_be(:guest) { create(:user).tap { |user| group.add_guest(user) } }
  let_it_be(:project_work_item, refind: true) { create(:work_item, project: project) }

  let(:work_item) { project_work_item }
  let(:mutation) { graphql_mutation(:workItemUpdate, input.merge('id' => work_item.to_global_id.to_s), fields) }

  let(:mutation_response) { graphql_mutation_response(:work_item_update) }

  shared_examples 'work item is not updated' do
    it 'ignores the update' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
        work_item.reload
      end.not_to change(&work_item_change)
    end
  end

  context 'with iteration widget input' do
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:old_iteration) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:new_iteration) { create(:iteration, iterations_cadence: cadence) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetIteration {
              iteration {
                id
              }
            }
          }
        }
        errors
      FIELDS
    end

    let(:iteration_id) { new_iteration.to_global_id.to_s }
    let(:input) { { 'iterationWidget' => { 'iterationId' => iteration_id } } }

    before do
      work_item.update!(iteration: old_iteration)
    end

    context 'when iterations feature is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(iterations: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.iteration } }
      end
    end

    context 'when iterations feature is licensed' do
      before do
        stub_licensed_features(iterations: true)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.iteration } }
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        shared_examples "work item's iteration is updated" do
          it "updates the work item's iteration" do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)

              work_item.reload
            end.to change(work_item, :iteration).from(old_iteration).to(new_iteration)

            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when setting to a new iteration' do
          it_behaves_like "work item's iteration is updated"
        end

        context 'when setting iteration to null' do
          let(:new_iteration) { nil }
          let(:iteration_id) { nil }

          it_behaves_like "work item's iteration is updated"
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item.iteration } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with weight widget input' do
    let(:new_weight) { 2 }
    let(:input) { { 'weightWidget' => { 'weight' => new_weight } } }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetWeight {
              weight
            }
            ... on WorkItemWidgetDescription {
              description
            }
          }
        }
        errors
      FIELDS
    end

    context 'when issuable weights is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(issue_weights: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.weight } }
      end
    end

    context 'when issuable weights is licensed' do
      before do
        stub_licensed_features(issue_weights: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it_behaves_like 'update work item weight widget'

        context 'when setting weight to null' do
          let(:input) do
            { 'weightWidget' => { 'weight' => nil } }
          end

          before do
            work_item.update!(weight: 2)
          end

          it 'updates the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change(work_item, :weight).from(2).to(nil)

            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when using quick action' do
          let(:input) { { 'descriptionWidget' => { 'description' => "/weight #{new_weight}" } } }

          it_behaves_like 'update work item weight widget'

          context 'when setting weight to null' do
            let(:input) { { 'descriptionWidget' => { 'description' => "/clear_weight" } } }

            before do
              work_item.update!(weight: 2)
            end

            it 'updates the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
                work_item.reload
              end.to change(work_item, :weight).from(2).to(nil)

              expect(response).to have_gitlab_http_status(:success)
            end
          end

          context 'when the work item type does not support the weight widget' do
            let_it_be(:work_item) { create(:work_item, :task, project: project) }

            let(:input) do
              { 'descriptionWidget' => { 'description' => "Updating weight.\n/weight 1" } }
            end

            before do
              WorkItems::Type.default_by_type(:task).widget_definitions
                .find_by_widget_type(:weight).update!(disabled: true)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item.weight } }
            end
          end
        end

        context 'when the work item is directly associated with a group' do
          let(:work_item) { create(:work_item, :group_level, namespace: group) }

          it_behaves_like 'update work item weight widget'
        end
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.weight } }
      end
    end
  end

  context 'with progress widget input' do
    let(:new_progress) { 50 }
    let(:new_current_value) { 30 }
    let(:new_start_value) { 10 }
    let(:new_end_value) { 50 }
    let(:input) do
      { 'progressWidget' => { 'current_value' => new_current_value, 'start_value' => new_start_value,
                              'end_value' => new_end_value } }
    end

    let_it_be_with_refind(:work_item) { create(:work_item, :objective, project: project) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetProgress {
              progress
              currentValue
              startValue
              endValue
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_progress
      work_item.progress&.progress
    end

    context 'when okrs is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(okrs: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_progress } }
      end
    end

    context 'when okrs is licensed' do
      before do
        stub_licensed_features(okrs: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it 'updates the progress widget' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item_progress }.from(nil).to(new_progress)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'progress' => new_progress,
              'type' => 'PROGRESS',
              'currentValue' => new_current_value,
              'startValue' => new_start_value,
              'endValue' => new_end_value
            }
          )
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_progress } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with color widget input' do
    let(:new_color) { '#346465' }
    let(:input) do
      { 'colorWidget' => { 'color' => new_color } }
    end

    let_it_be_with_refind(:work_item) { create(:work_item, :epic, namespace: group) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetColor {
              color
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_color
      work_item.color&.color
    end

    context 'when epic_colors is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(epic_colors: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_color } }
      end
    end

    context 'when epic_colors is licensed' do
      before do
        stub_licensed_features(epic_colors: true)
      end

      context 'when the user has permission to admin a work item' do
        let(:current_user) { reporter }

        it 'updates the color widget' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item_color }.from(nil).to(::Gitlab::Color.of(new_color))

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'color' => new_color,
              'type' => 'COLOR'
            }
          )
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_color } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with status widget input' do
    let(:new_status) { 'FAILED' }
    let(:input) { { 'statusWidget' => { 'status' => new_status } } }

    let_it_be_with_refind(:work_item) { create(:work_item, :satisfied_status, project: project) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetStatus {
              status
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_status
      state = work_item.requirement&.last_test_report_state
      ::WorkItems::Widgets::Status::STATUS_MAP[state]
    end

    context 'when requirements is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(requirements: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item_status } }
      end
    end

    context 'when requirements is licensed' do
      before do
        stub_licensed_features(requirements: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it_behaves_like 'update work item status widget'

        context 'when setting status to an invalid value' do
          # while a requirement can have a status 'unverified'
          # it can't be directly set that way

          let(:input) do
            { 'statusWidget' => { 'status' => 'UNVERIFIED' } }
          end

          it "does not update the work item's status" do
            # due to 'passed' internally and 'satisfied' externally, map it here
            expect(work_item_status).to eq("satisfied")

            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.not_to change { work_item_status }

            expect(work_item_status).to eq("satisfied")
          end
        end
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_status } }
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_status } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with health status widget input' do
    let(:new_status) { 'onTrack' }
    let(:input) { { 'healthStatusWidget' => { 'healthStatus' => new_status } } }

    let_it_be_with_refind(:work_item) do
      create(:work_item, health_status: :needs_attention, project: project)
    end

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetHealthStatus {
              healthStatus
            }
            ... on WorkItemWidgetDescription {
              description
            }
          }
        }
        errors
      FIELDS
    end

    context 'when issuable_health_status is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(issuable_health_status: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.health_status } }
      end
    end

    context 'when issuable_health_status is licensed' do
      before do
        stub_licensed_features(issuable_health_status: true)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.health_status } }
      end

      context 'when user has permissions to update the work item' do
        let(:current_user) { reporter }

        it 'updates work item health status' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item.health_status }.from('needs_attention').to('on_track')

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'healthStatus' => 'onTrack',
              'type' => 'HEALTH_STATUS'
            }
          )
        end

        context 'when using quick action' do
          let(:input) { { 'descriptionWidget' => { 'description' => "/health_status on_track" } } }

          it 'updates work item health status' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change { work_item.health_status }.from('needs_attention').to('on_track')

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'healthStatus' => 'onTrack',
                'type' => 'HEALTH_STATUS'
              }
            )
          end

          context 'when clearing health status' do
            let(:input) { { 'descriptionWidget' => { 'description' => "/clear_health_status" } } }

            it 'updates the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
                work_item.reload
              end.to change { work_item.health_status }.from('needs_attention').to(nil)

              expect(response).to have_gitlab_http_status(:success)
            end
          end

          context 'when the work item type does not support the health status widget' do
            let_it_be(:work_item) { create(:work_item, project: project) }

            let(:input) do
              { 'descriptionWidget' => { 'description' => "Updating health status.\n/health_status on_track" } }
            end

            before do
              WorkItems::Type.default_by_type(:issue).widget_definitions
                .find_by_widget_type(:health_status).update!(disabled: true)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item.health_status } }
            end
          end
        end
      end
    end
  end

  context 'with notes widget input' do
    let(:discussion_locked) { true }
    let(:input) { { 'notesWidget' => { 'discussionLocked' => true } } }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetNotes {
              discussionLocked
            }
          }
        }
        errors
      FIELDS
    end

    it_behaves_like 'work item is not updated' do
      let(:current_user) { guest }
      let(:work_item_change) { -> { work_item.discussion_locked } }
    end

    context 'when user has permissions to update the work item' do
      let(:current_user) { reporter }

      it 'updates work item discussion locked attribute on notes widget' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          work_item.reload
        end.to change { work_item.discussion_locked }.from(nil).to(true)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['workItem']['widgets']).to include(
          {
            'discussionLocked' => true,
            'type' => 'NOTES'
          }
        )
      end

      context 'when using quick action' do
        let(:input) { { 'descriptionWidget' => { 'description' => "/lock" } } }

        it 'updates work item discussion locked attribute on notes widget' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item.discussion_locked }.from(nil).to(true)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'discussionLocked' => true,
              'type' => 'NOTES'
            }
          )
        end

        context 'when unlocking discussion' do
          let(:input) { { 'descriptionWidget' => { 'description' => "/unlock" } } }

          before do
            work_item.update!(discussion_locked: true)
          end

          it 'updates work item discussion locked attribute on notes widget' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change { work_item.discussion_locked }.from(true).to(false)

            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when the work item type does not support the notes widget' do
          let(:input) do
            { 'descriptionWidget' => { 'description' => "Updating notes discussion locked.\n/lock" } }
          end

          before do
            WorkItems::Type.default_by_type(:issue).widget_definitions
              .find_by_widget_type(:notes).update!(disabled: true)
          end

          it_behaves_like 'work item is not updated' do
            let(:work_item_change) { -> { work_item.discussion_locked } }
          end
        end
      end
    end
  end
end
