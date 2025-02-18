# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRulesHelper, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:project_owner) { project.first_owner }

  let(:global_push_rule) { create(:push_rule_sample, project: project) }
  let(:push_rule) { create(:push_rule, project: project) }

  let(:possible_help_texts) do
    {
      commit_committer_check_base_help: /Users can only push commits to this repository if the committer email is one of their own verified emails/,
      reject_unsigned_commits_base_help: /Only signed commits can be pushed to this repository/,
      reject_non_dco_commits_base_help: %r{Only commits that include a <code>Signed-off-by:</code> element can be pushed to this repository},
      default_admin_help: /This setting will be applied to all projects unless overridden by an admin/,
      setting_can_be_overridden: /This setting is applied on the server level and can be overridden by an admin/,
      setting_has_been_overridden: /This setting is applied on the server level but has been overridden for this project/,
      requires_admin_contact: /Contact an admin to change this setting/
    }
  end

  let(:users) do
    {
      admin: admin,
      owner: project_owner
    }
  end

  where(:global_setting, :enabled_globally, :enabled_in_project, :current_user, :help_text, :invalid_text) do
    [
      [true,  true,  false, :admin, :default_admin_help,          nil],
      [true,  false, false, :admin, :default_admin_help,          nil],
      [true,  true,  true,  :admin, :default_admin_help,          nil],
      [true,  false, true,  :admin, :default_admin_help,          nil],
      [false, true,  nil,   :admin, :setting_can_be_overridden,   nil],
      [false, true,  nil,   :owner, :setting_can_be_overridden,   nil],
      [false, true,  nil,   :owner, :requires_admin_contact,      nil],
      [false, true,  false, :admin, :setting_has_been_overridden, nil],
      [false, true,  false, :owner, :setting_has_been_overridden, nil],
      [false, true,  false, :owner, :requires_admin_contact,      nil],
      [false, true,  true,  :owner, :setting_can_be_overridden,   nil],
      [false, true,  false, :owner, :setting_has_been_overridden, nil],
      [false, true,  true,  :owner, :requires_admin_contact,      :setting_has_been_overridden],
      [false, true,  false, :owner, :requires_admin_contact,      :setting_can_be_overridden],
      [false, false, true,  :admin, :base_help,                   :setting_can_be_overridden],
      [false, false, true,  :admin, :base_help,                   :setting_has_been_overridden]
    ]
  end

  with_them do
    PushRule::SETTINGS_WITH_GLOBAL_DEFAULT.each do |rule_attr|
      context "when `#{rule_attr}`" do
        before do
          global_push_rule.update_column(rule_attr, enabled_globally)
          push_rule.update_column(rule_attr, enabled_in_project)

          allow(helper).to receive(:current_user).and_return(users[current_user])
        end

        it "has the correct help text" do
          rule = global_setting ? global_push_rule : push_rule
          message = possible_help_texts["#{rule_attr}_#{help_text}".to_sym].presence || possible_help_texts[help_text]

          expect(helper.public_send("#{rule_attr}_description", rule)).to match(message)

          if invalid_text
            expect(helper.public_send("#{rule_attr}_description", rule)).not_to match(possible_help_texts[invalid_text])
          end
        end
      end
    end
  end

  describe '#commit_committer_name_check_description' do
    it 'returns the right description' do
      expect(
        helper.commit_committer_name_check_description(push_rule)
      ).to eq(s_("ProjectSettings|Users can only push commits to this repository "\
        "if the commit author name is consistent with their GitLab account name."))
    end
  end
end
