# frozen_string_literal: true

module QA
  module EE
    module Page
      module File
        module Show
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              include QA::Page::Component::ConfirmModal

              view 'ee/app/views/projects/blob/_owners.html.haml' do
                element :file_owner_content
                element :link_file_owner
              end

              # These two lock button elements can be removed when the refactor_blob_viewer feature flag is removed
              view 'ee/app/helpers/ee/lock_helper.rb' do
                element :lock_button
                element :disabled_lock_button
              end

              view 'app/assets/javascripts/repository/components/blob_button_group.vue' do
                element :lock_button, /data-qa-selector="lockBtnQASelector"/ # rubocop:disable QA/ElementWithPattern
                element :disabled_lock_button, /data-qa-selector="lockBtnQASelector"/ # rubocop:disable QA/ElementWithPattern
              end
            end
          end

          def lock
            click_element(:lock_button)
            click_confirmation_ok_button

            unless has_element?(:lock_button, text: 'Unlock')
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def unlock
            click_element(:lock_button)
            click_confirmation_ok_button

            unless has_element?(:lock_button, text: 'Lock')
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def has_lock_button_disabled?
            has_element?(:disabled_lock_button)
          end
        end
      end
    end
  end
end
