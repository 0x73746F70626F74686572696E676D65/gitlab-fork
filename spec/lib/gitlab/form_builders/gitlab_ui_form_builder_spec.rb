# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::FormBuilders::GitlabUiFormBuilder do
  include FormBuilderHelpers

  let_it_be(:user) { build(:user, :admin) }

  let_it_be(:form_builder) { described_class.new(:user, user, fake_action_view_base, {}) }

  describe '#gitlab_ui_checkbox_component' do
    context 'when not using slots' do
      let(:optional_args) { {} }

      subject(:checkbox_html) do
        form_builder.gitlab_ui_checkbox_component(
          :view_diffs_file_by_file,
          "Show one file at a time on merge request's Changes tab",
          **optional_args
        )
      end

      context 'without optional arguments' do
        it 'renders correct html' do
          expected_html = <<~EOS
            <div class="gl-form-checkbox custom-control custom-checkbox">
              <input name="user[view_diffs_file_by_file]" type="hidden" value="0" />
              <input class="custom-control-input" type="checkbox" value="1" name="user[view_diffs_file_by_file]" id="user_view_diffs_file_by_file" />
              <label class="custom-control-label" for="user_view_diffs_file_by_file">
                <span>Show one file at a time on merge request&#39;s Changes tab</span>
              </label>
            </div>
          EOS

          expect(html_strip_whitespace(checkbox_html)).to eq(html_strip_whitespace(expected_html))
        end
      end

      context 'with optional arguments' do
        let(:optional_args) do
          {
            help_text: 'Instead of all the files changed, show only one file at a time.',
            checkbox_options: { class: 'checkbox-foo-bar' },
            label_options: { class: 'label-foo-bar' },
            checked_value: '3',
            unchecked_value: '1'
          }
        end

        it 'renders help text' do
          expected_html = <<~EOS
            <div class="gl-form-checkbox custom-control custom-checkbox">
              <input name="user[view_diffs_file_by_file]" type="hidden" value="1" />
              <input class="custom-control-input checkbox-foo-bar" type="checkbox" value="3" name="user[view_diffs_file_by_file]" id="user_view_diffs_file_by_file" />
              <label class="custom-control-label label-foo-bar" for="user_view_diffs_file_by_file">
                <span>Show one file at a time on merge request&#39;s Changes tab</span>
                <p class="help-text" data-testid="pajamas-component-help-text">Instead of all the files changed, show only one file at a time.</p>
              </label>
            </div>
          EOS

          expect(html_strip_whitespace(checkbox_html)).to eq(html_strip_whitespace(expected_html))
        end
      end

      context 'with checkbox_options: { multiple: true }' do
        let(:optional_args) do
          {
            checkbox_options: { multiple: true },
            checked_value: 'one',
            unchecked_value: false
          }
        end

        it 'renders labels with correct for attributes' do
          expected_html = <<~EOS
            <div class="gl-form-checkbox custom-control custom-checkbox">
              <input class="custom-control-input" type="checkbox" value="one" name="user[view_diffs_file_by_file][]" id="user_view_diffs_file_by_file_one" />
              <label class="custom-control-label" for="user_view_diffs_file_by_file_one">
                <span>Show one file at a time on merge request&#39;s Changes tab</span>
              </label>
            </div>
          EOS

          expect(html_strip_whitespace(checkbox_html)).to eq(html_strip_whitespace(expected_html))
        end
      end
    end

    context 'when using slots' do
      subject(:checkbox_html) do
        form_builder.gitlab_ui_checkbox_component(
          :view_diffs_file_by_file
        ) do |c|
          c.label { "Show one file at a time on merge request's Changes tab" }
          c.help_text { 'Instead of all the files changed, show only one file at a time.' }
        end
      end

      it 'renders correct html' do
        expected_html = <<~EOS
          <div class="gl-form-checkbox custom-control custom-checkbox">
            <input name="user[view_diffs_file_by_file]" type="hidden" value="0" />
            <input class="custom-control-input" type="checkbox" value="1" name="user[view_diffs_file_by_file]" id="user_view_diffs_file_by_file" />
            <label class="custom-control-label" for="user_view_diffs_file_by_file">
              <span>Show one file at a time on merge request&#39;s Changes tab</span>
              <p class="help-text" data-testid="pajamas-component-help-text">Instead of all the files changed, show only one file at a time.</p>
            </label>
          </div>
        EOS

        expect(html_strip_whitespace(checkbox_html)).to eq(html_strip_whitespace(expected_html))
      end
    end
  end

  describe '#gitlab_ui_radio_component' do
    context 'when not using slots' do
      let(:optional_args) { {} }

      subject(:radio_html) do
        form_builder.gitlab_ui_radio_component(
          :access_level,
          :admin,
          "Admin",
          **optional_args
        )
      end

      context 'without optional arguments' do
        it 'renders correct html' do
          expected_html = <<~EOS
            <div class="gl-form-radio custom-control custom-radio">
              <input class="custom-control-input" type="radio" value="admin" checked="checked" name="user[access_level]" id="user_access_level_admin" />
              <label class="custom-control-label" for="user_access_level_admin">
                <span>Admin</span>
              </label>
            </div>
          EOS

          expect(html_strip_whitespace(radio_html)).to eq(html_strip_whitespace(expected_html))
        end
      end

      context 'with optional arguments' do
        let(:optional_args) do
          {
            help_text: 'Administrators have access to all groups, projects, and users and can manage all features in this installation',
            radio_options: { class: 'radio-foo-bar' },
            label_options: { class: 'label-foo-bar' }
          }
        end

        it 'renders help text' do
          expected_html = <<~EOS
            <div class="gl-form-radio custom-control custom-radio">
              <input class="custom-control-input radio-foo-bar" type="radio" value="admin" checked="checked" name="user[access_level]" id="user_access_level_admin" />
              <label class="custom-control-label label-foo-bar" for="user_access_level_admin">
                <span>Admin</span>
                <p class="help-text" data-testid="pajamas-component-help-text">Administrators have access to all groups, projects, and users and can manage all features in this installation</p>
              </label>
            </div>
          EOS

          expect(html_strip_whitespace(radio_html)).to eq(html_strip_whitespace(expected_html))
        end
      end
    end

    context 'when using slots' do
      subject(:radio_html) do
        form_builder.gitlab_ui_radio_component(
          :access_level,
          :admin
        ) do |c|
          c.label { "Admin" }
          c.help_text { 'Administrators have access to all groups, projects, and users and can manage all features in this installation' }
        end
      end

      it 'renders correct html' do
        expected_html = <<~EOS
          <div class="gl-form-radio custom-control custom-radio">
            <input class="custom-control-input" type="radio" value="admin" checked="checked" name="user[access_level]" id="user_access_level_admin" />
            <label class="custom-control-label" for="user_access_level_admin">
              <span>Admin</span>
              <p class="help-text" data-testid="pajamas-component-help-text">Administrators have access to all groups, projects, and users and can manage all features in this installation</p>
            </label>
          </div>
        EOS

        expect(html_strip_whitespace(radio_html)).to eq(html_strip_whitespace(expected_html))
      end
    end
  end

  private

  def html_strip_whitespace(html)
    html.lines.map(&:strip).join('')
  end
end
