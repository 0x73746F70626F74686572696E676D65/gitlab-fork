# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab Duo Chat', :js, feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  context 'for saas', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(user)
    end

    before do
      sign_in(user)
    end

    describe 'Feature enabled and available' do
      include_context 'with ai features enabled for group'

      before do
        visit root_path
      end

      shared_examples 'GitLab Duo drawer' do
        it 'opens the drawer to chat with GitLab Duo' do
          wait_for_requests

          within_testid('chat-component') do
            expect(page).to have_text('GitLab Duo Chat')
          end
        end
      end

      context "when opening the drawer from the breadcrumbs" do
        before do
          within_testid('top-bar') do
            click_button('GitLab Duo Chat')
          end
        end

        it_behaves_like 'GitLab Duo drawer'
      end
    end
  end

  context 'for self-managed', :with_cloud_connector do
    before do
      sign_in(user)
    end

    describe 'Feature enabled and available' do
      include_context 'with duo features enabled and ai chat available for self-managed'

      before do
        visit root_path
      end

      shared_examples 'GitLab Duo drawer' do
        it 'opens the drawer to chat with GitLab Duo' do
          wait_for_requests

          within_testid('chat-component') do
            expect(page).to have_text('GitLab Duo Chat')
          end
        end
      end

      context "when opening the drawer from the breadcrumbs" do
        before do
          within_testid('top-bar') do
            click_button('GitLab Duo Chat')
          end
        end

        it_behaves_like 'GitLab Duo drawer'
      end
    end
  end
end
