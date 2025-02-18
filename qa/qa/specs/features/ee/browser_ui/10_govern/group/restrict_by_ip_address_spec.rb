# frozen_string_literal: true

module QA
  RSpec.describe 'Govern' do
    describe 'Group access', :requires_admin, :skip_live_env, :blocking, product_group: :authentication do
      let(:admin_api_client) { Runtime::API::Client.as_admin }

      let(:sandbox_group) do
        Resource::Sandbox.fabricate! do |sandbox_group|
          sandbox_group.path = "gitlab-qa-ip-restricted-sandbox-group-#{SecureRandom.hex(8)}"
        end
      end

      let(:group) { create(:group, path: "ip-address-restricted-group-#{SecureRandom.hex(8)}", sandbox: sandbox_group) }
      let(:project) { create(:project, :with_readme, name: 'project-in-ip-restricted-group', group: group) }
      let(:user) { create(:user, api_client: admin_api_client) }
      let(:api_client) { Runtime::API::Client.new(:gitlab, user: user) }

      let!(:current_ip_address) do
        Flow::Login.while_signed_in(as: user) { user.reload!.api_response[:current_sign_in_ip] }
      end

      before do
        project.add_member(user)

        enable_plan_on_group(sandbox_group.path, "Gold") if Specs::Helpers::ContextSelector.dot_com?
        page.visit Runtime::Scenario.gitlab_address

        set_ip_address_restriction_to(ip_address)
      end

      after do
        sandbox_group.remove_via_api!
      end

      context 'when restricted by another ip address' do
        let(:ip_address) { get_next_ip_address(current_ip_address) }

        context 'with UI' do
          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347923' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!(skip_resp_code_check: true)
            expect(page).to have_text('Page Not Found')
            page.go_back

            group.visit!(skip_resp_code_check: true)
            expect(page).to have_text('Page Not Found')
            page.go_back
          end
        end

        context 'with API' do
          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347922' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd, except: { job: 'review-qa-*' } do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          after do
            key.remove_via_api!
          end

          it 'denies access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347921' do
            expect { push_a_project_with_ssh_key(key) }.to raise_error(
              QA::Support::Run::CommandError, /fatal: Could not read from remote repository/
            )
          end
        end
      end

      context 'when restricted by user\'s ip address' do
        let(:ip_address) { current_ip_address }

        context 'with UI' do
          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347926' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!
            expect(page).to have_text(group.sandbox.path)

            group.visit!
            expect(page).to have_text(group.path)
          end
        end

        context 'with API' do
          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347925' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd, except: { job: 'review-qa-*' } do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          after do
            key.remove_via_api!
          end

          it 'allows access', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347924' do
            expect { push_a_project_with_ssh_key(key) }.not_to raise_error
          end
        end
      end

      private

      def push_a_project_with_ssh_key(key)
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.group = sandbox_group
          push.ssh_key = key
          push.branch_name = "new_branch_#{SecureRandom.hex(8)}"
        end
      end

      def set_ip_address_restriction_to(ip_address)
        Flow::Login.while_signed_in_as_admin do
          group.sandbox.visit!

          Page::Group::Menu.perform(&:go_to_general_settings)

          Page::Group::Settings::General.perform do |settings|
            settings.set_ip_address_restriction(ip_address)
          end
        end
      end

      def get_next_ip_address(address)
        current_last_part = address.split(".").pop.to_i

        updated_last_part = current_last_part < 255 ? current_last_part + 1 : 1

        address.split(".")[0...-1].push(updated_last_part).join(".")
      end

      def enable_plan_on_group(group, plan)
        Flow::Login.while_signed_in_as_admin do
          Page::Main::Menu.perform(&:go_to_admin_area)
          Page::Admin::Menu.perform(&:go_to_groups_overview)

          Page::Admin::Overview::Groups::Index.perform do |index|
            index.search_group(group)
            index.click_group(group)
          end

          Page::Admin::Overview::Groups::Show.perform(&:click_edit_group_link)

          Page::Admin::Overview::Groups::Edit.perform do |edit|
            edit.select_plan(plan)
            edit.click_save_changes_button
          end
        end
      end

      def create_request(api_endpoint)
        Runtime::API::Request.new(api_client, api_endpoint)
      end
    end
  end
end
