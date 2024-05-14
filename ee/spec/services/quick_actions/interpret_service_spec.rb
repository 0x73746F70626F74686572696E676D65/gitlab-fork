# frozen_string_literal: true

require 'spec_helper'

RSpec.describe QuickActions::InterpretService, feature_category: :team_planning do
  let(:current_user) { create(:user) }
  let(:developer) { create(:user) }
  let(:developer2) { create(:user) }
  let(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :public, group: group) }
  let_it_be_with_reload(:issue) { create(:issue, project: project) }

  let(:service) { described_class.new(container: project, current_user: current_user) }

  before do
    stub_licensed_features(multiple_issue_assignees: true,
      multiple_merge_request_reviewers: true,
      multiple_merge_request_assignees: true)

    project.add_developer(current_user)
    project.add_developer(developer)
  end

  shared_examples 'quick action is unavailable' do |action|
    it 'does not recognize action' do
      expect(service.available_commands(target).map { |command| command[:name] }).not_to include(action)
    end
  end

  shared_examples 'quick action is available' do |action|
    it 'does recognize action' do
      expect(service.available_commands(target).map { |command| command[:name] }).to include(action)
    end
  end

  shared_examples 'failed command' do |error_msg|
    let(:match_msg) { error_msg ? eq(error_msg) : be_empty }

    it 'populates {} if content contains an unsupported command' do
      _, updates, _ = service.execute(content, issuable)

      expect(updates).to be_empty
    end

    it "returns #{error_msg || 'an empty'} message" do
      _, _, message = service.execute(content, issuable)

      expect(message).to match_msg
    end
  end

  describe '#execute' do
    let(:merge_request) { create(:merge_request, source_project: project) }

    context 'assign command' do
      context 'there is a group' do
        let(:group) { create(:group) }

        before do
          group.add_developer(user)
          group.add_developer(user2)
          group.add_developer(user3)
        end

        it 'assigns to group members' do
          cmd = "/assign #{group.to_reference}"

          _, updates, _ = service.execute(cmd, issue)

          expect(updates).to include(assignee_ids: match_array([user.id, user2.id, user3.id]))
        end

        it 'does not assign to more than QuickActions::UsersFinder::MAX_QUICK_ACTION_USERS' do
          stub_const('Gitlab::QuickActions::UsersExtractor::MAX_QUICK_ACTION_USERS', 2)

          cmd = "/assign #{group.to_reference}"

          _, updates, messages = service.execute(cmd, issue)

          expect(updates).to be_blank
          expect(messages).to include('Too many users')
        end
      end

      context 'Issue' do
        it 'fetches assignees and populates them if content contains /assign' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/unassign @#{user2.username}\n/assign @#{user3.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id, user3.id])
        end

        context 'with test_case issue type' do
          it 'does not mark to update assignee' do
            test_case = create(:quality_test_case, project: project)

            _, updates = service.execute("/assign @#{user3.username}", test_case)

            expect(updates[:assignee_ids]).to eq(nil)
          end
        end

        context 'assign command with multiple assignees' do
          it 'fetches assignee and populates assignee_ids if content contains /assign' do
            issue.update!(assignee_ids: [user.id])

            _, updates = service.execute("/unassign @#{user.username}\n/assign @#{user2.username} @#{user3.username}", issue)

            expect(updates[:assignee_ids]).to match_array([user2.id, user3.id])
          end
        end
      end

      context 'Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'fetches assignees and populates them if content contains /assign' do
          merge_request.update!(assignee_ids: [user.id])

          _, updates = service.execute("/assign @#{user2.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([user.id, user2.id])
        end

        context 'assign command with a group of users' do
          let(:group) { create(:group) }
          let(:project) { create(:project, group: group) }
          let(:group_members) { create_list(:user, 3) }
          let(:command) { "/assign #{group.to_reference}" }

          before do
            group_members.each { group.add_developer(_1) }
          end

          it 'adds group members' do
            merge_request.update!(assignee_ids: [user.id])

            _, updates = service.execute(command, merge_request)

            expect(updates[:assignee_ids]).to match_array [user.id, *group_members.map(&:id)]
          end
        end

        context 'assign command with multiple assignees' do
          it 'fetches assignee and populates assignee_ids if content contains /assign' do
            merge_request.update!(assignee_ids: [user.id])

            _, updates = service.execute("/assign @#{user.username}\n/assign @#{user2.username} @#{user3.username}", issue)

            expect(updates[:assignee_ids]).to match_array([user.id, user2.id, user3.id])
          end

          context 'unlicensed' do
            before do
              stub_licensed_features(multiple_merge_request_assignees: false)
            end

            it 'does not recognize /assign with multiple user references' do
              merge_request.update!(assignee_ids: [user.id])

              _, updates = service.execute("/assign @#{user2.username} @#{user3.username}", merge_request)

              expect(updates[:assignee_ids]).to match_array([user2.id])
            end
          end
        end
      end
    end

    context 'assign_reviewer command' do
      context 'with a merge request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'fetches reviewers and populates them if content contains /assign_reviewer' do
          merge_request.update!(reviewer_ids: [user.id])

          _, updates = service.execute("/assign_reviewer @#{user2.username}\n/assign_reviewer @#{user3.username}", merge_request)

          expect(updates[:reviewer_ids]).to match_array([user.id, user2.id, user3.id])
        end

        context 'assign command with multiple reviewers' do
          it 'assigns multiple reviewers while respecting previous assignments' do
            merge_request.update!(reviewer_ids: [user.id])

            _, updates = service.execute("/assign_reviewer @#{user.username}\n/assign_reviewer @#{user2.username} @#{user3.username}", merge_request)

            expect(updates[:reviewer_ids]).to match_array([user.id, user2.id, user3.id])
          end
        end
      end
    end

    context 'unassign_reviewer command' do
      let(:content) { '/unassign_reviewer' }
      let(:merge_request) { create(:merge_request, source_project: project) }

      context 'unassign_reviewer command with multiple assignees' do
        it 'unassigns both reviewers if content contains /unassign_reviewer @user @user1' do
          merge_request.update!(reviewer_ids: [user.id, user2.id, user3.id])

          _, updates = service.execute("/unassign_reviewer @#{user.username} @#{user2.username}", merge_request)

          expect(updates[:reviewer_ids]).to match_array([user3.id])
        end

        it 'does not unassign reviewers if the content cannot be parsed' do
          merge_request.update!(reviewer_ids: [user.id, user2.id, user3.id])

          _, updates, msg = service.execute("/unassign_reviewer nobody", merge_request)

          expect(updates[:reviewer_ids]).to be_nil
          expect(msg).to eq "Could not apply unassign_reviewer command. Failed to find users for 'nobody'."
        end

        context 'with "me" alias' do
          context 'when the current user is referenced both by username and "me"' do
            let(:content) do
              <<-QUICKACTION
/assign me
/assign_reviewer #{developer2.to_reference} #{current_user.to_reference}
/unassign_reviewer me
              QUICKACTION
            end

            it 'will correctly remove the reviewer' do
              _, updates, _ = service.execute(content, merge_request)

              expect(updates[:reviewer_ids]).to match_array([developer2.id])
            end
          end
        end
      end
    end

    context 'unassign command' do
      let(:content) { '/unassign' }

      context 'Issue' do
        it 'unassigns user if content contains /unassign @user' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign @#{user2.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id, user3.id])
        end

        it 'unassigns both users if content contains /unassign @user @user1' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign @#{user2.username} @#{user3.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id])
        end

        it 'unassigns all the users if content contains /unassign' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign", issue)

          expect(updates[:assignee_ids]).to be_empty
        end

        it 'does not apply command if the argument cannot be parsed' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates, msg = service.execute("/assign nobody", issue)

          expect(updates[:assignee_ids]).to be_nil
          expect(msg).to eq "Could not apply assign command. Failed to find users for 'nobody'."
        end
      end

      context 'with a Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'unassigns user if content contains /unassign @user' do
          merge_request.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/unassign @#{user2.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([user.id])
        end

        describe 'applying unassign command with multiple assignees' do
          it 'unassigns both users if content contains /unassign @user @user1' do
            merge_request.update!(assignee_ids: [user.id, user2.id, user3.id])

            _, updates = service.execute("/unassign @#{user.username} @#{user2.username}", merge_request)

            expect(updates[:assignee_ids]).to match_array([user3.id])
          end

          context 'when unlicensed' do
            before do
              stub_licensed_features(multiple_merge_request_assignees: false)
            end

            it 'does not recognize /unassign @user' do
              merge_request.update!(assignee_ids: [user.id, user2.id, user3.id])

              _, updates = service.execute("/unassign @#{user.username}", merge_request)

              expect(updates[:assignee_ids]).to be_empty
            end
          end
        end
      end
    end

    context 'reassign command' do
      let(:content) { "/reassign @#{current_user.username}" }

      context 'Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        context 'unlicensed' do
          before do
            stub_licensed_features(multiple_merge_request_assignees: false)
          end

          it 'does not recognize /reassign @user' do
            _, updates = service.execute(content, merge_request)

            expect(updates).to be_empty
          end
        end

        it 'reassigns user if content contains /reassign @user' do
          _, updates = service.execute("/reassign @#{current_user.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([current_user.id])
        end

        context 'it reassigns multiple users' do
          let(:additional_user) { create(:user) }

          it 'reassigns user if content contains /reassign @user' do
            _, updates = service.execute("/reassign @#{current_user.username} @#{additional_user.username}", merge_request)

            expect(updates[:assignee_ids]).to match_array([current_user.id, additional_user.id])
          end
        end
      end

      context 'Issue' do
        let(:content) { "/reassign @#{current_user.username}" }

        before do
          issue.update!(assignee_ids: [user.id])
        end

        context 'unlicensed' do
          before do
            stub_licensed_features(multiple_issue_assignees: false)
          end

          it 'does not recognize /reassign @user' do
            _, updates = service.execute(content, issue)

            expect(updates).to be_empty
          end
        end

        it 'reassigns user if content contains /reassign @user' do
          _, updates = service.execute("/reassign @#{current_user.username}", issue)

          expect(updates[:assignee_ids]).to match_array([current_user.id])
        end

        context 'with test_case issue type' do
          it 'does not mark to update assignee' do
            test_case = create(:quality_test_case, project: project)

            _, updates = service.execute("/reassign @#{current_user.username}", test_case)

            expect(updates[:assignee_ids]).to eq(nil)
          end
        end

        context 'it reassigns multiple users' do
          let(:additional_user) { create(:user) }

          it 'reassigns user if content contains /reassign @user' do
            _, updates = service.execute("/reassign @#{current_user.username} @#{additional_user.username}", issue)

            expect(updates[:assignee_ids]).to match_array([current_user.id, additional_user.id])
          end
        end
      end
    end

    context 'reassign_reviewer command' do
      let(:content) { "/reassign_reviewer @#{current_user.username}" }

      context 'unlicensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: false)
        end

        it 'does not recognize /reassign_reviewer @user' do
          content = "/reassign_reviewer @#{current_user.username}"
          _, updates = service.execute(content, merge_request)

          expect(updates).to be_empty
        end
      end

      it 'reassigns reviewer if content contains /reassign_reviewer @user' do
        _, updates = service.execute("/reassign_reviewer @#{current_user.username}", merge_request)

        expect(updates[:reviewer_ids]).to match_array([current_user.id])
      end
    end

    context 'iteration command' do
      let_it_be(:root_group) { create(:group, :private) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be(:project) { create(:project, :private, :repository, group: group) }

      context 'when iterations are enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        context 'when iteration exists' do
          let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

          let(:content) { "/iteration #{iteration.to_reference(project)}" }

          context 'with permissions' do
            before do
              group.add_developer(current_user)
            end

            it 'does not assign iteration when reference does not match any iteration' do
              _, updates, message = service.execute("/iteration *iteration:#{non_existing_record_id}", issue)

              expect(updates).to be_empty
              expect(message).to eq(_("Could not apply iteration command. Failed to find the referenced iteration."))
            end

            it 'assigns an iteration to an issue' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to eq(iteration: iteration)
              expect(message).to eq("Set the iteration to #{iteration.to_reference}.")
            end

            context 'when iteration is started' do
              before do
                iteration.start!
              end

              it 'assigns an iteration to an issue' do
                _, updates, message = service.execute(content, issue)

                expect(updates).to eq(iteration: iteration)
                expect(message).to eq("Set the iteration to #{iteration.to_reference}.")
              end
            end

            context 'when issuable is an incident' do
              let(:incident) { create(:incident, project: project) }

              it 'assigns an iteration' do
                _, updates, message = service.execute(content, incident)

                expect(updates).to eq(iteration: iteration)
                expect(message).to eq("Set the iteration to #{iteration.to_reference}.")
              end
            end
          end

          context 'when the user does not have enough permissions' do
            before do
              allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
              allow(current_user).to receive(:can?).with(:admin_issue, project).and_return(false)
            end

            it 'returns an error message' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq('Could not apply iteration command.')
            end
          end
        end

        context 'with --current and --next options' do
          before do
            group.add_developer(current_user)
          end

          context "with iterations cadence reference" do
            let_it_be(:cadence) { create(:iterations_cadence, title: "one cadence", group: root_group) }
            let_it_be(:past_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.ago) }
            let_it_be(:current_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }
            let_it_be(:next_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.from_now) }

            let_it_be(:another_cadence) { create(:iterations_cadence, title: "another cadence", group: root_group) }
            let_it_be(:another_current_iteration) { create(:iteration, :with_due_date, iterations_cadence: another_cadence, start_date: 2.days.ago) }

            let_it_be(:empty_cadence) { create(:iterations_cadence, title: "empty cadence", group: root_group) }

            let_it_be(:inaccessible_cadence) { create(:iterations_cadence, title: "another cadence") }

            it 'does not assign any iteration when the referenced cadence is empty' do
              _, updates, message = service.execute("/iteration #{empty_cadence.to_reference} --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. No current iteration found for the cadence.'))

              _, updates, message = service.execute("/iteration #{empty_cadence.to_reference} --next", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. No upcoming iteration found for the cadence.'))
            end

            it 'does not assign any iteration when referencing non-existent iterations cadence' do
              _, updates, message = service.execute("/iteration [cadence:\"foobar cadence\"] --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))

              _, updates, message = service.execute("/iteration [cadence:#{non_existing_record_id}] --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))
            end

            it 'does not assign any iteration when referencing unauthorized iterations cadence' do
              _, updates, message = service.execute("/iteration #{inaccessible_cadence.to_reference} --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))
            end

            it 'does not assign any iteration when option are missing' do
              _, updates, message = service.execute("/iteration #{cadence.to_reference}", issue)
              expect(updates).to be_empty
              expect(message).to eq(_("Could not apply iteration command. Missing option --current or --next."))
            end

            context 'with --current option' do
              where(:content) do
                [
                  [lazy { "/iteration #{cadence.to_reference} --current" }],
                  [lazy { "/iteration [cadence:\"#{cadence.title}\"] --current" }]
                ]
              end

              with_them do
                it 'assigns the current iteration of the referenced iterations cadence' do
                  _, updates, message = service.execute(content, issue)

                  expect(updates).to eq(iteration: current_iteration)
                  expect(message).to eq("Set the iteration to #{current_iteration.to_reference}.")
                end
              end
            end

            context 'with --next option' do
              where(:content) do
                [
                  [lazy { "/iteration #{cadence.to_reference} --next" }],
                  [lazy { "/iteration [cadence:\"#{cadence.title}\"] --next" }]
                ]
              end

              with_them do
                it 'assigns the next upcoming iteration of the referenced iterations cadence' do
                  _, updates, message = service.execute(content, issue)

                  expect(updates).to eq(iteration: next_iteration)
                  expect(message).to eq("Set the iteration to #{next_iteration.to_reference}.")
                end
              end
            end
          end

          context "without iterations cadence reference" do
            let_it_be(:cadence) { create(:iterations_cadence, title: "cadence", group: group) }
            let_it_be(:current_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }
            let_it_be(:next_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.from_now) }

            context 'when a group hierarchy has a single iterations cadence' do
              it 'assigns the current iteration from the iterations cadence' do
                _, updates, message = service.execute("/iteration --current", issue)

                expect(updates).to eq(iteration: current_iteration)
                expect(message).to eq("Set the iteration to #{current_iteration.to_reference}.")
              end

              it 'assigns the next iteration from the iterations cadence' do
                _, updates, message = service.execute("/iteration --next", issue)

                expect(updates).to eq(iteration: next_iteration)
                expect(message).to eq("Set the iteration to #{next_iteration.to_reference}.")
              end
            end

            context 'when a group hierarchy has multiple iterations cadences' do
              before_all do
                create(:iterations_cadence, title: "another cadence", group: group)
              end

              it 'does not assign any iteration' do
                _, updates, message = service.execute("/iteration --current", issue)
                expect(updates).to be_empty
                expect(message).to eq(_('Could not apply iteration command. There are multiple cadences but no cadence is specified.'))

                _, updates, message = service.execute("/iteration --next", issue)
                expect(updates).to be_empty
                expect(message).to eq(_('Could not apply iteration command. There are multiple cadences but no cadence is specified.'))
              end
            end
          end
        end
      end

      context 'when iterations are disabled' do
        let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

        let(:content) { "/iteration #{iteration.to_reference(project)}" }

        before do
          stub_licensed_features(iterations: false)
        end

        it 'does not recognize /iteration' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end
    end

    context 'remove_iteration command' do
      let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

      let(:content) { '/remove_iteration' }

      context 'when iterations are enabled' do
        before do
          stub_licensed_features(iterations: true)
          issue.update!(iteration: iteration)
        end

        it 'removes an assigned iteration from an issue' do
          _, updates, message = service.execute(content, issue)

          expect(updates).to eq(iteration: nil)
          expect(message).to eq("Removed #{iteration.to_reference} iteration.")
        end

        context 'when issuable is an incident' do
          let(:incident) { create(:incident, project: project, iteration: iteration) }

          it 'removes an assigned iteration' do
            _, updates, message = service.execute(content, incident)

            expect(updates).to eq(iteration: nil)
            expect(message).to eq("Removed #{iteration.to_reference} iteration.")
          end
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, project).and_return(false)
          end

          it 'returns an error message' do
            _, updates, message = service.execute(content, issue)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply remove_iteration command.')
          end
        end
      end

      context 'when iterations are disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'does not recognize /remove_iteration' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end
    end

    context 'epic command' do
      let_it_be_with_reload(:epic) { create(:epic, group: group) }
      let_it_be_with_reload(:private_epic) { create(:epic, group: create(:group, :private)) }
      let(:content) { "/epic #{epic.to_reference(project)}" }

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when epic exists' do
          it 'assigns an issue to an epic' do
            _, updates, message = service.execute(content, issue)

            expect(updates).to eq(epic: epic)
            expect(message).to eq('Added an issue to an epic.')
          end

          context 'when it is confidential' do
            before do
              epic.update!(confidential: true)
              group.add_developer(current_user)
            end

            it 'shows an error' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq('Cannot assign a confidential epic to a non-confidential issue. Make the issue confidential and try again')
            end
          end

          context 'when an issue belongs to a project without group' do
            let(:user_project) { create(:project) }
            let(:issue)        { create(:issue, project: user_project) }

            before do
              user_project.add_guest(user)
            end

            it 'does not assign an issue to an epic' do
              _, updates = service.execute(content, issue)

              expect(updates).to be_empty
            end
          end

          context 'when issue is already added to epic' do
            it 'returns error message' do
              issue = create(:issue, project: project, epic: epic)

              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq("Issue #{issue.to_reference} has already been added to epic #{epic.to_reference}.")
            end
          end

          context 'when issuable does not support epics' do
            it 'does not assign an incident to an epic' do
              incident = create(:incident, project: project)

              _, updates = service.execute(content, incident)

              expect(updates).to be_empty
            end
          end
        end

        context 'when epic does not exist' do
          let(:content) { "/epic none" }

          it 'does not assign an issue to an epic' do
            _, updates, message = service.execute(content, issue)

            expect(updates).to be_empty
            expect(message).to eq("This epic does not exist or you don't have sufficient permission.")
          end
        end

        context 'when user has no permissions to read epic' do
          let(:content) { "/epic #{private_epic.to_reference(project)}" }

          it 'does not assign an issue to an epic' do
            _, updates, message = service.execute(content, issue)

            expect(updates).to be_empty
            expect(message).to eq("This epic does not exist or you don't have sufficient permission.")
          end
        end

        context 'when user has no access to the issue' do
          before do
            allow(current_user).to receive(:can?).and_call_original
            allow(current_user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
          end

          it 'returns error' do
            _, updates, message = service.execute(content, issue)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply epic command.')
          end
        end
      end

      context 'when epics are disabled' do
        it 'does not recognize /epic' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end
    end

    context 'label command for epics' do
      let(:epic) { create(:epic, group: group) }
      let(:label) { create(:group_label, title: 'bug', group: group) }
      let(:project_label) { create(:label, title: 'project_label') }
      let(:content) { "/label ~#{label.title} ~#{project_label.title}" }

      let(:service) { described_class.new(container: group, current_user: current_user) }

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when a user has permissions to label an epic' do
          before do
            group.add_developer(current_user)
          end

          it 'populates valid label ids' do
            _, updates = service.execute(content, epic)

            expect(updates).to eq(add_label_ids: [label.id])
          end
        end

        context 'when a user does not have permissions to label an epic' do
          it 'does not populate any labels' do
            _, updates = service.execute(content, epic)

            expect(updates).to be_empty
          end
        end
      end

      context 'when epics are disabled' do
        it 'does not populate any labels' do
          group.add_developer(current_user)

          _, updates = service.execute(content, epic)

          expect(updates).to be_empty
        end
      end
    end

    context 'remove_epic command' do
      let(:epic) { create(:epic, group: group) }
      let(:content) { "/remove_epic" }

      before do
        stub_licensed_features(epics: true)
        issue.update!(epic: epic)
      end

      context 'when epics are disabled' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not recognize /remove_epic' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end

      context 'when subepics are enabled' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'unassigns an issue from an epic' do
          _, updates = service.execute(content, issue)

          expect(updates).to eq(epic: nil)
        end
      end

      context 'when issuable does not support epics' do
        it 'does not recognize /remove_epic' do
          incident = create(:incident, project: project, epic: epic)

          _, updates = service.execute(content, incident)

          expect(updates).to be_empty
        end
      end

      context 'when user has no access to the issue' do
        before do
          allow(current_user).to receive(:can?).and_call_original
          allow(current_user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
        end

        it 'returns error' do
          _, updates, message = service.execute(content, issue)

          expect(updates).to be_empty
          expect(message).to eq('Could not apply remove_epic command.')
        end
      end
    end

    context 'epic hierarchy commands' do
      it_behaves_like 'execute epic hierarchy commands'
    end

    shared_examples 'weight command' do
      it 'populates weight specified by the /weight command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: weight)
      end
    end

    shared_examples 'clear weight command' do
      it 'populates weight: nil if content contains /clear_weight' do
        issuable.update!(weight: 5)

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: nil)
      end

      it 'unsets weight if weight is 0' do
        issuable.update!(weight: 0)

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: nil)
      end
    end

    context 'issuable weights licensed' do
      let(:issuable) { issue }

      before do
        stub_licensed_features(issue_weights: true)
      end

      context 'weight' do
        let(:content) { "/weight #{weight}" }

        it_behaves_like 'weight command' do
          let(:weight) { 5 }
        end

        it_behaves_like 'weight command' do
          let(:weight) { 0 }
        end

        context 'when weight is negative' do
          it 'does not populate weight' do
            content = "/weight -10"
            _, updates = service.execute(content, issuable)

            expect(updates).to be_empty
          end
        end
      end

      context 'clear_weight' do
        it_behaves_like 'clear weight command' do
          let(:content) { '/clear_weight' }
        end
      end
    end

    context 'issuable weights unlicensed' do
      before do
        stub_licensed_features(issue_weights: false)
      end

      it 'does not recognise /weight X' do
        _, updates = service.execute('/weight 5', issue)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_weight' do
        _, updates = service.execute('/clear_weight', issue)

        expect(updates).to be_empty
      end
    end

    context 'issuable weights not supported by type' do
      let_it_be(:incident) { create(:incident, project: project) }

      before do
        stub_licensed_features(issue_weights: true)
      end

      it 'does not recognise /weight X' do
        _, updates = service.execute('/weight 5', incident)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_weight' do
        _, updates = service.execute('/clear_weight', incident)

        expect(updates).to be_empty
      end
    end

    shared_examples 'health_status command' do
      it 'populates health_status specified by the /health_status command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to eq(health_status: health_status)
      end
    end

    shared_examples 'clear_health_status command' do
      it 'populates health_status: nil if content contains /clear_health_status' do
        issuable.update!(health_status: 'on_track')

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(health_status: nil)
      end
    end

    context 'issuable health statuses licensed' do
      let(:issuable) { issue }

      before do
        stub_licensed_features(issuable_health_status: true)
      end

      context 'health_status' do
        let(:content) { "/health_status #{health_status}" }

        it_behaves_like 'health_status command' do
          let(:health_status) { 'on_track' }
        end

        it_behaves_like 'health_status command' do
          let(:health_status) { 'at_risk' }
        end

        context 'when health_status is invalid' do
          it 'does not populate health_status' do
            content = "/health_status unknown"
            _, updates = service.execute(content, issuable)

            expect(updates).to be_empty
          end
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, issuable).and_return(false)
          end

          it 'returns an error message' do
            content = "/health_status on_track"
            _, updates, message = service.execute(content, issuable)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply health_status command.')
          end
        end
      end

      context 'clear_health_status' do
        it_behaves_like 'clear_health_status command' do
          let(:content) { '/clear_health_status' }
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, issuable).and_return(false)
          end

          it 'returns an error message' do
            content = "/clear_health_status"
            _, updates, message = service.execute(content, issuable)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply clear_health_status command.')
          end
        end
      end
    end

    context 'issuable health_status unlicensed' do
      before do
        stub_licensed_features(issuable_health_status: false)
      end

      it 'does not recognise /health_status X' do
        _, updates = service.execute('/health_status needs_attention', issue)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_health_status' do
        _, updates = service.execute('/clear_health_status', issue)

        expect(updates).to be_empty
      end
    end

    context 'issuable health_status not supported by type' do
      let_it_be(:incident) { create(:incident, project: project) }

      before do
        stub_licensed_features(issuable_health_status: true)
      end

      it 'does not recognise /health_status X' do
        _, updates = service.execute('/health_status on_track', incident)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_health_status' do
        _, updates = service.execute('/clear_health_status', incident)

        expect(updates).to be_empty
      end
    end

    shared_examples 'empty command' do
      it 'populates {} if content contains an unsupported command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to be_empty
      end
    end

    context 'not persisted merge request can not be merged' do
      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'not approved merge request can not be merged' do
      before do
        merge_request.target_project.update!(approvals_before_merge: 1)
      end

      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'when the merge request is not approved' do
      let!(:rule) { create(:any_approver_rule, merge_request: merge_request, approvals_required: 1) }
      let(:content) { '/merge' }

      context 'when "merge_when_checks_pass" is enabled' do
        let(:service) do
          described_class.new(
            container: project,
            current_user: current_user,
            params: { merge_request_diff_head_sha: merge_request.diff_head_sha }
          )
        end

        it 'runs merge command and returns merge message' do
          _, updates, message = service.execute(content, merge_request)

          expect(updates).to eq(merge: merge_request.diff_head_sha)

          expect(message).to eq('Scheduled to merge this merge request (Merge when checks pass).')
        end
      end

      context 'when "merge_when_checks_pass" is disabled' do
        before do
          stub_feature_flags(merge_when_checks_pass: false)
        end

        it_behaves_like 'failed command', 'Could not apply merge command.' do
          let(:issuable) { merge_request }
        end
      end
    end

    context 'when the merge request is blocked' do
      let(:content) { '/merge' }
      let(:issuable) { create(:merge_request, :blocked, source_project: project) }

      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      context 'when merge_when_checks_pass is enabled' do
        let(:service) do
          described_class.new(
            container: project,
            current_user: current_user,
            params: { merge_request_diff_head_sha: issuable.diff_head_sha }
          )
        end

        it 'runs merge command and returns merge message' do
          _, updates, message = service.execute(content, issuable)

          expect(updates).to eq(merge: issuable.diff_head_sha)

          expect(message).to eq('Scheduled to merge this merge request (Merge when checks pass).')
        end
      end

      context 'when merge_when_checks_pass id disabled' do
        before do
          stub_feature_flags(merge_when_checks_pass: false)
        end

        it_behaves_like 'failed command', 'Could not apply merge command.'
      end
    end

    context 'approved merge request can be merged' do
      before do
        merge_request.update!(approvals_before_merge: 1)
        merge_request.approvals.create!(user: current_user)
      end

      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'confidential command' do
      context 'for test cases' do
        it 'does mark to update confidential attribute' do
          issuable = create(:quality_test_case, project: project)

          _, updates, message = service.execute('/confidential', issuable)

          expect(message).to eq('Made this issue confidential.')
          expect(updates[:confidential]).to eq(true)
        end
      end

      context 'for requirements' do
        it 'fails supports confidentiality condition' do
          issuable = create(:issue, :requirement, project: project)

          _, updates, message = service.execute('/confidential', issuable)

          expect(message).to eq('Could not apply confidential command.')
          expect(updates[:confidential]).to be_nil
        end
      end

      context 'for epics' do
        let_it_be(:target_epic) { create(:epic, group: group) }
        let(:content) { '/confidential' }

        before do
          stub_licensed_features(epics: true)
          group.add_developer(current_user)
        end

        shared_examples 'command not applied' do
          it 'returns unsuccessful execution message' do
            _, updates, message = service.execute(content, target_epic)

            expect(message).to eq(execution_message)
            expect(updates[:confidential]).to eq(true)
          end
        end

        it 'returns correct explain message' do
          _, explanations = service.explain(content, target_epic)

          expect(explanations).to match_array(['Makes this epic confidential.'])
        end

        it 'returns successful execution message' do
          _, updates, message = service.execute(content, target_epic)

          expect(message).to eq('Made this epic confidential.')
          expect(updates[:confidential]).to eq(true)
        end

        context 'when epic has non-confidential issues' do
          before do
            target_epic.update!(confidential: false)
            issue.update!(confidential: false)
            create(:epic_issue, epic: target_epic, issue: issue)
          end

          it_behaves_like 'command not applied' do
            let_it_be(:execution_message) do
              'Cannot make the epic confidential if it contains non-confidential issues'
            end
          end
        end

        context 'when epic has non-confidential epics' do
          before do
            target_epic.update!(confidential: false)
            create(:epic, group: group, parent: target_epic, confidential: false)
          end

          it_behaves_like 'command not applied' do
            let_it_be(:execution_message) do
              'Cannot make the epic confidential if it contains non-confidential child epics'
            end
          end
        end

        context 'when a user has no permissions to set confidentiality' do
          before do
            group.add_guest(current_user)
          end

          it 'does not update epic confidentiality' do
            _, updates, message = service.execute(content, target_epic)

            expect(message).to eq('Could not apply confidential command.')
            expect(updates[:confidential]).to be_nil
          end
        end
      end
    end

    context 'blocking issues commands' do
      let(:user) { current_user }

      it_behaves_like 'issues link quick action', :blocks
      it_behaves_like 'issues link quick action', :blocked_by
    end

    context 'unlink command' do
      let_it_be(:other_issue) { create(:issue, project: project) }
      let(:content) { "/unlink #{other_issue.to_reference(issue)}" }

      subject(:unlink_issues) { service.execute(content, issue) }

      shared_examples 'command applied successfully' do
        it 'executes command successfully' do
          expect { unlink_issues }.to change { IssueLink.count }.by(-1)
          expect(unlink_issues[2]).to eq("Removed link with #{other_issue.to_reference(issue)}.")
          expect(issue.notes.last.note).to eq("removed the relation with #{other_issue.to_reference}")
          expect(other_issue.notes.last.note).to eq("removed the relation with #{issue.to_reference}")
        end
      end

      context 'when command includes blocking issue' do
        before do
          create(:issue_link, source: other_issue, target: issue, link_type: 'blocks')
        end

        it_behaves_like 'command applied successfully'
      end

      context 'when command includes blocked issue' do
        before do
          create(:issue_link, source: issue, target: other_issue, link_type: 'blocks')
        end

        it_behaves_like 'command applied successfully'
      end

      context 'when provided issue is not linked' do
        it 'fails to execute command' do
          expect { unlink_issues }.not_to change { IssueLink.count }
          expect(unlink_issues[2]).to eq('No linked issue matches the provided parameter.')
        end
      end
    end

    it_behaves_like 'quick actions that change work item type ee'

    context 'ai_review command' do
      let(:content) { '/ai_review' }
      let(:allowed?) { true }

      before do
        allow(merge_request)
          .to receive(:ai_review_merge_request_allowed?)
          .with(current_user)
          .and_return(allowed?)
      end

      it 'calls Llm::ReviewMergeRequestService#execute' do
        expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
          expect(svc).to receive(:execute)
        end

        service.execute(content, merge_request)
      end

      context 'when user is not allowed to execute quick action' do
        let(:allowed?) { false }

        it 'does not call Llm::ReviewMergeRequestService#execute' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          service.execute(content, merge_request)
        end
      end
    end
  end

  describe '#explain' do
    describe 'health_status command' do
      let(:content) { '/health_status on_track' }

      context 'issuable health statuses licensed' do
        before do
          stub_licensed_features(issuable_health_status: true)
        end

        it 'includes the value' do
          _, explanations = service.explain(content, issue)
          expect(explanations).to eq(['Sets health status to on_track.'])
        end
      end
    end

    describe 'unassign command' do
      let(:content) { '/unassign' }
      let(:issue) { create(:issue, project: project, assignees: [user, user2]) }

      it "includes all assignees' references" do
        _, explanations = service.explain(content, issue)

        expect(explanations).to eq(["Removes assignees @#{user.username} and @#{user2.username}."])
      end
    end

    describe 'unassign command with assignee references' do
      let(:content) { "/unassign @#{user.username} @#{user3.username}" }
      let(:issue) { create(:issue, project: project, assignees: [user, user2, user3]) }

      it 'includes only selected assignee references' do
        _, explanations = service.explain(content, issue)

        expect(explanations.first).to match(/Removes assignees/)
        expect(explanations.first).to match("@#{user3.username}")
        expect(explanations.first).to match("@#{user.username}")
      end
    end

    describe 'weight command' do
      let(:content) { '/weight 4' }

      it 'includes the number' do
        _, explanations = service.explain(content, issue)
        expect(explanations).to eq(['Sets weight to 4.'])
      end
    end

    describe 'blocking issues commands' do
      let_it_be(:guest) { create(:user) }
      let_it_be(:restricted_project) { create(:project) }
      let_it_be(:ref1) { create(:issue, project: project).to_reference }
      let_it_be(:ref2) { create(:issue, project: project).to_reference }

      let(:target) { issue }

      before do
        issue.project.add_guest(guest)
      end

      context 'with /blocks' do
        let(:blocks_command) { "/blocks #{ref1} #{ref2}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_developer(current_user)
          end

          it '/blocks is available' do
            _, explanations = service.explain(blocks_command, issue)

            expect(explanations).to contain_exactly("Set this issue as blocking #{[ref1, ref2].to_sentence}.")
          end

          context 'when licensed feature is not available' do
            before do
              stub_licensed_features(blocked_issues: false)
            end

            it_behaves_like 'quick action is unavailable', :blocks
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :blocks
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :blocks
        end
      end

      context 'with /blocked_by' do
        let(:blocked_by_command) { "/blocked_by #{ref1} #{ref2}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_guest(current_user)
          end

          it '/blocked_by is available' do
            _, explanations = service.explain(blocked_by_command, issue)

            expect(explanations)
              .to contain_exactly("Set this issue as blocked by #{[ref1, ref2].to_sentence}.")
          end

          context 'when licensed feature is not available' do
            before do
              stub_licensed_features(blocked_issues: false)
            end

            it_behaves_like 'quick action is unavailable', :blocked_by
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :blocked_by
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :blocked_by
        end
      end
    end

    describe 'promote_to command' do
      let(:content) { '/promote_to objective' }

      context 'when work item supports promotion' do
        let_it_be(:key_result) { build(:work_item, :key_result, project: project) }

        it 'includes the value' do
          _, explanations = service.explain(content, key_result)
          expect(explanations).to eq(['Promotes item to objective.'])
        end
      end

      context 'when work item does not support promotion' do
        let_it_be(:requirement) { build(:work_item, :requirement, project: project) }

        it 'does not include the value' do
          _, explanations = service.explain(content, requirement)
          expect(explanations).to be_empty
        end
      end
    end

    describe 'checkin_reminder command' do
      let(:checkin_reminder_command) { "/checkin_reminder weekly" }

      context 'for a work item type that supports reminders' do
        let(:objective) { create(:work_item, :objective, project: project, author: current_user) }

        it '/checkin_reminder is available' do
          _, explanations = service.explain(checkin_reminder_command, objective)

          expect(explanations).to contain_exactly("Sets checkin reminder frequency to weekly.")
        end
      end

      context 'for a work item type that does not support reminders' do
        let(:key_result) { create(:work_item, :key_result, project: project) }

        it '/checkin_reminder is available' do
          _, explanations = service.explain(checkin_reminder_command, key_result)

          expect(explanations).not_to contain_exactly("Sets checkin reminder frequency to weekly.")
        end
      end
    end

    describe 'epic hierarchy commands' do
      it_behaves_like 'explain epic hierarchy commands'
    end
  end
end
