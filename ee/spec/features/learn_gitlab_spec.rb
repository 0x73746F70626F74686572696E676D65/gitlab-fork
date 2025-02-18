# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Learn Gitlab concerns', :feature, :js, :saas, feature_category: :onboarding do
  include Features::InviteMembersModalHelpers

  context 'with an active trial' do
    let_it_be(:group) do
      create(
        :group_with_plan, :private,
        plan: :ultimate_trial_plan, trial_starts_on: Date.today, trial_ends_on: 10.days.from_now
      ) do |g|
        create(:onboarding_progress, namespace: g)
      end
    end

    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { project.creator }
    let(:alert_selector) { '[data-testid="unlimited-members-during-trial-alert"]' }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_ee_application_setting(dashboard_limit_enabled: true)

      sign_in(user)
    end

    it 'displays alert with Explore paid plans link and Invite more members button' do
      visit namespace_project_learn_gitlab_path(group, project)

      expect(page).to have_selector(alert_selector)
      expect(page).to have_link(text: 'Explore paid plans', href: group_billings_path(group))
      expect(page).to have_button('Invite more members')

      click_button 'Invite more members'

      expect(page).to have_selector(invite_modal_selector)
    end
  end

  context 'with learn gitlab links' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    context 'with completed links' do
      before do
        yesterday = Date.yesterday
        create(
          :onboarding_progress,
          namespace: namespace,
          issue_created_at: yesterday,
          git_write_at: yesterday,
          pipeline_created_at: yesterday,
          merge_request_created_at: yesterday,
          user_added_at: yesterday,
          license_scanning_run_at: yesterday
        )
      end

      it 'renders correct completed sections' do
        sign_in(user)
        visit namespace_project_learn_gitlab_path(namespace, project)

        expect_completed_section('Create an issue')
        expect_completed_section('Create a repository')
        expect_completed_section("Set up your first project's CI/CD")
        expect_completed_section('Submit a merge request (MR)')
        expect_completed_section('Invite your colleagues')
        expect_completed_section('Scan dependencies for licenses')
      end
    end

    context 'without completion progress' do
      before_all do
        create(:onboarding_progress, namespace: namespace)
      end

      it 'renders correct links and navigates to project issues' do
        sign_in(user)
        visit namespace_project_learn_gitlab_path(namespace, project)

        issue_link = find_link('Create an issue')

        expect_correct_candidate_link(issue_link, project_issues_path(project))
        expect_correct_candidate_link(find_link('Create a repository'), project_path(project))
        expect_correct_candidate_link(find_link('Invite your colleagues'), '#')
        expect_correct_candidate_link(find_link("Set up your first project's CI/CD"), project_pipelines_path(project))
        expect_correct_candidate_link(find_link('Submit a merge request (MR)'), project_merge_requests_path(project))

        expect_correct_candidate_link(
          find_link('Analyze your application for vulnerabilities with DAST'),
          project_security_configuration_path(project, anchor: 'dast')
        )

        expect_correct_candidate_link(
          find_link('Start a free trial of GitLab Ultimate'),
          new_trial_path(glm_content: 'onboarding-start-trial')
        )

        expect_correct_candidate_link(
          find_link('Enable require merge approvals'),
          new_trial_path(glm_content: 'onboarding-require-merge-approvals')
        )

        expect_correct_candidate_link(
          find_link('Add code owners'),
          new_trial_path(glm_content: 'onboarding-code-owners')
        )

        issue_link.click
        expect(page).to have_current_path(project_issues_path(project))
      end

      context 'with invite members link opening invite modal' do
        before do
          sign_in(user)
          visit namespace_project_learn_gitlab_path(namespace, project)
        end

        it 'launches invite modal when invite is clicked' do
          click_link('Invite your colleagues')

          page.within invite_modal_selector do
            expect(page).to have_content("You're inviting members to the #{project.name} project")
          end
        end
      end
    end

    def expect_completed_section(text)
      expect(page).to have_no_link(text)
      expect(page).to have_css('.gl-text-green-500', text: text)
    end

    def expect_correct_candidate_link(link, path)
      expect(link['href']).to include(path)
      expect(link['data-testid']).to eq('uncompleted-learn-gitlab-link')
    end
  end
end
