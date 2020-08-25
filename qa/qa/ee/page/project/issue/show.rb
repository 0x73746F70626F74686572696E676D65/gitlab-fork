# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Issue
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/sidebar/components/weight/weight.vue' do
                  element :weight_label_value
                  element :edit_weight_link
                  element :remove_weight_link
                  element :weight_input_field
                  element :weight_no_value_content
                end
              end
            end

            def click_remove_weight_link
              click_element(:remove_weight_link)
            end

            def set_weight(weight)
              click_element(:edit_weight_link)
              fill_element(:weight_input_field, weight)
              send_keys_to_element(:weight_input_field, :enter)
            end

            def weight_label_value
              find_element(:weight_label_value)
            end

            def weight_no_value_content
              find_element(:weight_no_value_content)
            end

            def wait_for_attachment_replication(image_url, max_wait: Runtime::Geo.max_file_replication_time)
              QA::Runtime::Logger.debug(%Q[#{self.class.name} - wait_for_attachment_replication])
              wait_until_geo_max_replication_time(max_wait: max_wait) do
                asset_exists?(image_url)
              end
            end

            def wait_until_geo_max_replication_time(max_wait: Runtime::Geo.max_file_replication_time)
              wait_until(max_duration: max_wait) { yield }
            end
          end
        end
      end
    end
  end
end
