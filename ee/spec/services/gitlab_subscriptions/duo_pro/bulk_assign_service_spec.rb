# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoPro::BulkAssignService, feature_category: :seat_cost_management do
  describe '#execute' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

    context 'on Gitlab.com' do
      subject(:bulk_assign) do
        described_class.new(add_on_purchase: add_on_purchase,
          user_ids: user_ids).execute
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'with different namespace memberships' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: namespace, add_on: add_on)
        end

        context 'when users are members' do
          let(:user_ids) { User.where(username: expected_assigned_users).map(&:id) }
          let(:expected_assigned_users) do
            %w[guest_of_namespace member_of_subgroup member_of_project member_of_shared_group member_of_shared_project]
          end

          before_all do
            namespace.add_guest(create(:user, username: 'guest_of_namespace'))
            subgroup = create(:group, parent: namespace)
            subgroup.add_developer(create(:user, username: 'member_of_subgroup'))
            project = create(:project, namespace: namespace)
            project.add_developer(create(:user, username: 'member_of_project'))
            invited_group = create(:group)
            create(:group_group_link, { shared_with_group: invited_group, shared_group: namespace })
            invited_group.add_developer(create(:user, username: 'member_of_shared_group'))
            project_with_link = create(:project, namespace: namespace)
            create(:project_group_link, project: project_with_link, group: invited_group)
            invited_group.add_developer(create(:user, username: 'member_of_shared_project'))
          end

          it 'assigns the users' do
            response = bulk_assign
            expect(response.success?).to be_truthy
            expect(response[:users].map(&:id)).to match_array(user_ids)
          end
        end

        context 'when users are not members' do
          let(:user_ids) { User.where(username: 'not_member_of_namespace').map(&:id) }

          let(:expected_logs) do
            {
              add_on_purchase_id: add_on_purchase.id,
              message: 'Duo Pro Bulk User Assignment',
              response_type: 'error',
              payload: { errors: 'INVALID_USER_ID_PRESENT', user_ids: Set[100_0000] }
            }
          end

          before do
            create(:user, id: 100_0000, username: 'not_member_of_namespace')
          end

          it 'does not assign the user' do
            expect(Gitlab::AppLogger).to receive(:error).with(expected_logs)

            response = bulk_assign
            expect(response.error?).to be_truthy
            expect(response.message).to eq('INVALID_USER_ID_PRESENT')
          end
        end

        context 'when users are not found' do
          let(:user_ids) { [non_existing_record_id] }

          let(:expected_logs) do
            {
              add_on_purchase_id: add_on_purchase.id,
              message: 'Duo Pro Bulk User Assignment',
              response_type: 'error',
              payload: { errors: 'INVALID_USER_ID_PRESENT', user_ids: Set[non_existing_record_id] }
            }
          end

          it 'does not assign the user' do
            expect(Gitlab::AppLogger).to receive(:error).with(expected_logs)

            response = bulk_assign
            expect(response.error?).to be_truthy
            expect(response.message).to eq('INVALID_USER_ID_PRESENT')
          end
        end
      end

      context 'with multiple users assignments' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:expected_assigned_users) do
          User.where(username: (1..3).map { |i| "code_suggestions_user#{i}" })
        end

        let(:user_ids) { expected_assigned_users.map(&:id) }

        before_all do
          3.times do |i|
            namespace.add_developer(create(:user, username: "code_suggestions_user#{i + 1}"))
          end
        end

        context 'with enough seats' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: namespace, add_on: add_on)
          end

          let(:expected_logs) do
            assigned_users_ids = namespace.gitlab_duo_pro_eligible_user_ids
            {
              add_on_purchase_id: add_on_purchase.id,
              message: 'Duo Pro Bulk User Assignment',
              response_type: 'success',
              payload: { users: assigned_users_ids }
            }
          end

          it 'executes a limited number of queries', :use_clean_rails_redis_caching do
            control = ActiveRecord::QueryRecorder.new { bulk_assign }
            expect(control.count).to be <= 11
          end

          it 'returns assigned and not eligible users' do
            expect(Gitlab::AppLogger).to receive(:info).with(expected_logs)

            response = bulk_assign

            expect(response.success?).to be_truthy
            expect(response[:users].map(&:id)).to eq(user_ids)
          end

          it 'calls the iterable triggers worker', :sidekiq_inline do
            expect(::Onboarding::CreateIterableTriggersWorker).to receive(:perform_async).with(namespace.id, user_ids)
                                                                                         .and_call_original

            bulk_assign
          end

          context 'when a user is already assigned' do
            let_it_be(:user) { create(:user) }
            let_it_be(:user_2) { create(:user) }
            let_it_be(:user_3) { create(:user) }
            let_it_be(:service_instance) do
              described_class.new(
                add_on_purchase: add_on_purchase,
                user_ids: [user.id, user_2.id, user_3.id]
              )
            end

            before_all do
              add_on_purchase.update!(quantity: 3)
              namespace.add_developer(user)
              namespace.add_developer(user_2)
              namespace.add_developer(user_3)
              create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
            end

            subject(:response) { service_instance.execute }

            it 'excludes the assigned user when checking seats but still return it' do
              expect(response.success?).to be_truthy
              expect(response[:users].map(&:id)).to match_array([user.id, user_2.id, user_3.id])
            end
          end

          context 'with resource locking' do
            let(:users) { create_list(:user, 3) }

            before do
              add_on_purchase.update!(quantity: 1)
            end

            it 'prevents from double booking assignment' do
              expect(add_on_purchase.assigned_users.count).to eq(0)

              # Create threads to execute BulkAssignService for each user
              threads = users.map do |user|
                namespace.add_developer(user)

                Thread.new do
                  described_class.new(
                    add_on_purchase: add_on_purchase,
                    user_ids: [user.id]
                  ).execute
                end
              end
              threads.each(&:join)

              expect(add_on_purchase.assigned_users.count).to eq(1)
            end

            context 'when NoSeatsAvailableError is raised' do
              let_it_be(:user) { create(:user) }
              let_it_be(:service_instance) do
                described_class.new(
                  add_on_purchase: add_on_purchase,
                  user_ids: [user.id]
                )
              end

              let_it_be(:expected_logs) do
                {
                  add_on_purchase_id: add_on_purchase.id,
                  message: 'Duo Pro Bulk User Assignment',
                  response_type: 'error',
                  payload: { errors: 'NOT_ENOUGH_SEATS' }
                }
              end

              before_all do
                namespace.add_developer(user)
              end

              subject(:response) { service_instance.execute }

              it 'handles the error correctly' do
                # Mocking first call to return true to pass validate_enough_seats
                expect(service_instance).to receive(:seats_available?).and_return(true)
                expect(service_instance).to receive(:seats_available?).and_return(false)
                expect(Gitlab::AppLogger).to receive(:error).with(expected_logs)

                expect(response.error?).to be_truthy
                expect { response }.not_to raise_error
                expect(response.errors).to eq(['NOT_ENOUGH_SEATS'])
              end
            end
          end
        end

        context 'with not enough seats' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, quantity: 2, namespace: namespace, add_on: add_on)
          end

          let(:error_message) { 'NOT_ENOUGH_SEATS' }

          let(:expected_logs) do
            {
              add_on_purchase_id: add_on_purchase.id,
              message: 'Duo Pro Bulk User Assignment',
              response_type: 'error',
              payload: { errors: error_message }
            }
          end

          it 'executes a limited number of queries', :use_clean_rails_redis_caching do
            control = ActiveRecord::QueryRecorder.new { bulk_assign }
            expect(control.count).to be <= 1
          end

          it 'returns errors' do
            expect(Gitlab::AppLogger).to receive(:error).with(expected_logs)

            response = bulk_assign
            expect(response.error?).to be_truthy
            expect(response.message).to eq(error_message)
          end

          it 'does not create any iterable triggers' do
            expect(::Onboarding::CreateIterableTriggersWorker).not_to receive(:perform_async)

            bulk_assign
          end
        end
      end
    end
  end
end
