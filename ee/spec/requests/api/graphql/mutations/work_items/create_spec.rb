# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let(:mutation_response) { graphql_mutation_response(:work_item_create) }
  let(:widgets_response) { mutation_response['workItem']['widgets'] }
  let(:type_response) { mutation_response['workItem']['workItemType'] }

  context 'when user has permissions to create a work item' do
    let(:current_user) { developer }

    shared_examples 'creates work item with iteration widget' do
      let(:fields) do
        <<~FIELDS
          workItem {
            workItemType {
              name
            }
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

      context 'when setting iteration on work item creation' do
        let_it_be(:cadence) { create(:iterations_cadence, group: group) }
        let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }

        let(:input) do
          {
            title: 'new title',
            workItemTypeId: WorkItems::Type.default_by_type(:task).to_global_id.to_s,
            iterationWidget: { 'iterationId' => iteration.to_global_id.to_s }
          }
        end

        before do
          stub_licensed_features(iterations: true)
        end

        it "sets the work item's iteration", :aggregate_failures do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItem.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(type_response).to include({ 'name' => 'Task' })
          expect(widgets_response).to include(
            {
              'type' => 'ITERATION',
              'iteration' => { 'id' => iteration.to_global_id.to_s }
            }
          )
        end

        context 'when iterations feature is unavailable' do
          before do
            stub_licensed_features(iterations: false)
          end

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/383322
          # We prefer to return an error rather than nil when authorization for an object fails.
          # Here the authorization fails due to the unavailability of the licensed feature.
          # Because the object to be authorized gets loaded via argument inside an InputObject,
          # we need to add an additional hook to Types::BaseInputObject so errors are raised.
          it 'returns nil' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(0)

            expect(mutation_response).to be_nil
          end
        end
      end

      context 'when creating a key result' do
        let_it_be(:parent) { create(:work_item, :objective, **container_params) }

        let(:fields) do
          <<~FIELDS
            workItem {
              id
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetHierarchy {
                  parent {
                    id
                  }
                }
              }
            }
            errors
          FIELDS
        end

        let(:input) do
          {
            title: 'key result',
            workItemTypeId: WorkItems::Type.default_by_type(:key_result).to_global_id.to_s,
            hierarchyWidget: { 'parentId' => parent.to_global_id.to_s }
          }
        end

        context 'when okrs are available' do
          before do
            stub_licensed_features(okrs: true)
          end

          it 'creates the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => 'Key Result' })
            expect(widgets_response).to include(
              {
                'parent' => { 'id' => parent.to_global_id.to_s },
                'type' => 'HIERARCHY'
              }
            )
          end
        end

        context 'when okrs are not available' do
          before do
            stub_licensed_features(okrs: false)
          end

          it 'returns error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to not_change(WorkItem, :count)

            expect(mutation_response['errors'])
              .to contain_exactly(/cannot be added: it's not allowed to add this type of parent item/)
            expect(mutation_response['workItem']).to be_nil
          end
        end
      end

      context 'when group_webhooks feature is available', :aggregate_failures do
        let(:input) do
          {
            title: 'new title',
            workItemTypeId: WorkItems::Type.default_by_type(:task).to_global_id.to_s
          }
        end

        before do
          stub_licensed_features(group_webhooks: true)
          create(:group_hook, issues_events: true, group: group)
        end

        it 'creates a work item' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { WorkItem.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
        end
      end
    end

    context 'when creating work items in a project' do
      context 'with projectPath' do
        let_it_be(:container_params) { { project: project } }
        let(:mutation) { graphql_mutation(:workItemCreate, input.merge(projectPath: project.full_path), fields) }
        let(:work_item_type) { :task }

        it_behaves_like 'creates work item with iteration widget'
      end

      context 'with namespacePath' do
        let_it_be(:container_params) { { project: project } }
        let(:mutation) { graphql_mutation(:workItemCreate, input.merge(namespacePath: project.full_path), fields) }
        let(:work_item_type) { :task }

        it_behaves_like 'creates work item with iteration widget'
      end
    end

    context 'when creating work items in a group' do
      let_it_be(:container_params) { { namespace: group } }
      let(:mutation) { graphql_mutation(:workItemCreate, input.merge(namespacePath: group.full_path), fields) }
      let(:work_item_type) { :epic }

      it_behaves_like 'creates work item with iteration widget'

      context 'with rolledup dates widget input' do
        before do
          stub_licensed_features(epics: true)
        end

        let(:fields) do
          <<~FIELDS
          workItem {
            workItemType {
              name
            }
            widgets {
              type
                ... on WorkItemWidgetRolledupDates {
                  startDate
                  startDateFixed
                  startDateIsFixed
                  startDateSourcingWorkItem {
                    id
                  }
                  startDateSourcingMilestone {
                    id
                  }
                  dueDate
                  dueDateFixed
                  dueDateIsFixed
                  startDateSourcingWorkItem {
                    id
                  }
                  dueDateSourcingMilestone {
                    id
                  }
                }
            }
          }
          errors
          FIELDS
        end

        context "when the work_items_rolledup_dates feature flag is disabled" do
          before do
            stub_feature_flags(work_items_rolledup_dates: false)
          end

          let(:start_date) { 5.days.ago.to_date }
          let(:due_date) { 5.days.from_now.to_date }

          let(:input) do
            {
              title: "some WI",
              workItemTypeId: WorkItems::Type.default_by_type(work_item_type).to_gid.to_s,
              rolledupDatesWidget: {
                startDateFixed: start_date.to_s,
                dueDateFixed: due_date.to_s
              }
            }
          end

          it "does not set the work item's start and due date" do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              "type" => "ROLLEDUP_DATES",
              "dueDate" => nil,
              "dueDateFixed" => nil,
              "dueDateIsFixed" => nil,
              "dueDateSourcingMilestone" => nil,
              "startDate" => nil,
              "startDateFixed" => nil,
              "startDateIsFixed" => nil,
              "startDateSourcingMilestone" => nil,
              "startDateSourcingWorkItem" => nil
            )
          end
        end

        context "with fixed dates" do
          let(:start_date) { 5.days.ago.to_date }
          let(:due_date) { 5.days.from_now.to_date }

          let(:input) do
            {
              title: "some WI",
              workItemTypeId: WorkItems::Type.default_by_type(work_item_type).to_gid.to_s,
              rolledupDatesWidget: {
                startDateIsFixed: true,
                startDateFixed: start_date.to_s,
                dueDateIsFixed: true,
                dueDateFixed: due_date.to_s
              }
            }
          end

          it "sets the work item's start and due date" do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { WorkItem.count }
              .by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              "type" => "ROLLEDUP_DATES",
              "dueDate" => due_date.to_s,
              "dueDateFixed" => due_date.to_s,
              "dueDateIsFixed" => true,
              "dueDateSourcingMilestone" => nil,
              "startDate" => start_date.to_s,
              "startDateFixed" => start_date.to_s,
              "startDateIsFixed" => true,
              "startDateSourcingMilestone" => nil,
              "startDateSourcingWorkItem" => nil
            )
          end
        end
      end

      context 'with health status widget input' do
        let(:new_status) { 'onTrack' }
        let(:input) do
          {
            title: "some WI",
            workItemTypeId: WorkItems::Type.default_by_type(work_item_type).to_gid.to_s,
            healthStatusWidget: { healthStatus: new_status }
          }
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetHealthStatus {
                  healthStatus
                }
              }
            }
            errors
          FIELDS
        end

        context 'when issuable_health_status is licensed' do
          before do
            stub_licensed_features(epics: true, issuable_health_status: true)
          end

          it 'sets value for the health status widget' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'healthStatus' => 'onTrack',
                'type' => 'HEALTH_STATUS'
              }
            )
          end
        end

        context 'when issuable_health_status is unlicensed' do
          before do
            stub_licensed_features(epics: true, issuable_health_status: false)
          end

          it 'returns an error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(0)

            expect(mutation_response).to be_nil
            expect(graphql_errors).to include(a_hash_including(
              'message' => "Following widget keys are not supported by Epic type: [:health_status_widget]"
            ))
          end
        end
      end

      context 'with color widget input' do
        let(:new_color) { '#346465' }
        let(:input) do
          {
            title: "some WI",
            workItemTypeId: WorkItems::Type.default_by_type(work_item_type).to_gid.to_s,
            colorWidget: { color: new_color }
          }
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
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

        context 'when epic_colors is licensed' do
          before do
            stub_licensed_features(epics: true, epic_colors: true)
          end

          it 'sets value for color widget' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'color' => new_color,
                'type' => 'COLOR'
              }
            )
          end
        end

        context 'when epic_colors is unlicensed' do
          before do
            stub_licensed_features(epics: true, epic_colors: false)
          end

          it 'returns an error' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(0)

            expect(mutation_response).to be_nil
            expect(graphql_errors).to include(a_hash_including(
              'message' => "Following widget keys are not supported by Epic type: [:color_widget]"
            ))
          end
        end
      end

      context 'with assignees widget input containing multiple assignees' do
        let_it_be(:assignees) { create_list(:user, 2, developer_of: project) }

        let(:fields) do
          <<~FIELDS
            workItem {
              workItemType {
                name
              }
              widgets {
                type
                ... on WorkItemWidgetAssignees {
                  assignees {
                    nodes {
                      id
                      username
                    }
                  }
                }
              }
            }
            errors
          FIELDS
        end

        let(:input) do
          {
            title: 'some WI',
            workItemTypeId: WorkItems::Type.default_by_type(work_item_type).to_gid.to_s,
            assigneesWidget: { 'assigneeIds' => assignees.map(&:to_gid).map(&:to_s) }
          }
        end

        context 'when multiple_issue_assignees is licensed' do
          before do
            stub_licensed_features(epics: true, multiple_issue_assignees: true)
          end

          it "sets the work item's assignees" do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              {
                'assignees' => { 'nodes' => [
                  { 'id' => assignees[0].to_gid.to_s, 'username' => assignees[0].username },
                  { 'id' => assignees[1].to_gid.to_s, 'username' => assignees[1].username }
                ] },
                'type' => 'ASSIGNEES'
              }
            )
          end
        end

        context 'when multiple_issue_assignees is unlicensed' do
          before do
            stub_licensed_features(epics: true, multiple_issue_assignees: false)
          end

          it 'assigns only the first assignee' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
            end.to change { WorkItem.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(type_response).to include({ 'name' => work_item_type.to_s.capitalize })
            expect(widgets_response).to include(
              {
                'assignees' => { 'nodes' => [
                  { 'id' => assignees[0].to_gid.to_s, 'username' => assignees[0].username }
                ] },
                'type' => 'ASSIGNEES'
              }
            )
          end
        end
      end
    end
  end
end
