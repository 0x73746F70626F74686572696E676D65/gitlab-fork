# frozen_string_literal: true

module QA
  module EE
    module Resource
      class WorkItemEpic < QA::Resource::Base
        include Support::Dates

        attribute :group do
          QA::Resource::Group.fabricate_via_api! do |group|
            group.path = "group-to-test-epic-work-items-#{SecureRandom.hex(8)}"
          end
        end

        attributes :id,
          :iid,
          :title,
          :description,
          :labels,
          :start_date_is_fixed,
          :start_date_fixed,
          :due_date_is_fixed,
          :due_date_fixed,
          :confidential,
          :author,
          :start_date,
          :due_date

        def initialize
          @title = "WI-Epic-#{SecureRandom.hex(8)}"
          @description = "This is a work item epic description."
          @confidential = false
          @start_date_is_fixed = false
          @due_date_is_fixed = false
        end

        def fabricate!
          raise NotImplementedError
        end

        def gid
          "gid://gitlab/WorkItem/#{id}"
        end

        # Work item epic attributes
        #
        # @return [String]
        def gql_attributes
          @gql_attributes ||= <<~GQL
            author {
              id
            }
            confidential
            createdAt
            updatedAt
            closedAt
            description
            id
            state
            title
            widgets {
              ... on WorkItemWidgetRolledupDates
              {
                dueDate
                dueDateFixed
                dueDateIsFixed
                startDate
                startDateFixed
                startDateIsFixed
              }
              ... on WorkItemWidgetLabels
              {
                labels
                {
                  nodes
                  {
                    title
                  }
                }
              }
              ... on WorkItemWidgetAwardEmoji
              {
                upvotes
                downvotes
              }
              ... on WorkItemWidgetColor
              {
                color
                textColor
              }
            }
            workItemType {
              name
              id
            }
          GQL
        end

        # Path for fetching work item epic
        #
        # @return [String]
        def api_get_path
          "/graphql"
        end

        # Fetch work item epic
        #
        # @return [Hash]
        def api_get
          process_api_response(
            api_post_to(
              api_get_path,
              <<~GQL
                query {
                  workItem(id: "#{gid}") {
                    #{gql_attributes}
                  }
                }
              GQL
            )
          )
        end

        # Path to create work item epic
        #
        # @return [String]
        def api_post_path
          "/graphql"
        end

        # Return subset of variable date fields for comparing work item epics with legacy epics
        # Can be removed after migration to work item epics is complete
        #
        # @return [Hash]
        def epic_dates
          reload! if api_response.nil?

          api_resource.slice(
            :created_at,
            :updated_at,
            :closed_at
          )
        end

        # Return author field for comparing work item epics with legacy epics
        # Can be removed after migration to work item epics is complete
        #
        # @return [Hash]
        def epic_author
          reload! if api_response.nil?

          api_resource[:author][:id] = api_resource.dig(:author, :id).split('/').last.to_i

          api_resource.slice(
            :author
          )
        end

        protected

        # rubocop:disable Metrics/AbcSize -- temp comparable for epic to work items migration
        # Return subset of fields for comparing work item epics to legacy epics
        #
        # @return [Hash]
        def comparable
          reload! unless api_response.nil?

          api_resource[:state] = convert_graphql_state_to_legacy_state(api_resource[:state])
          api_resource[:labels] = api_resource.dig(:widgets, 3, :labels, :nodes)
          api_resource[:upvotes] = api_resource.dig(:widgets, 9, :upvotes)
          api_resource[:downvotes] = api_resource.dig(:widgets, 9, :downvotes)
          api_resource[:start_date] = api_resource.dig(:widgets, 12, :start_date)
          api_resource[:due_date] = api_resource.dig(:widgets, 12, :due_date)
          api_resource[:start_date_is_fixed] = api_resource.dig(:widgets, 12, :start_date_is_fixed)
          api_resource[:start_date_fixed] = api_resource.dig(:widgets, 12, :start_date_fixed)
          api_resource[:due_date_is_fixed] = api_resource.dig(:widgets, 12, :due_date_is_fixed)
          api_resource[:due_date_fixed] = api_resource.dig(:widgets, 12, :due_date_fixed)
          api_resource[:color] = api_resource.dig(:widgets, 15, :color)
          api_resource[:text_color] = api_resource.dig(:widgets, 15, :text_color)

          api_resource.slice(
            :title,
            :description,
            :state,
            :start_date,
            :due_date,
            :start_date_is_fixed,
            :start_date_fixed,
            :due_date_is_fixed,
            :due_date_fixed,
            :confidential,
            :labels,
            :upvotes,
            :downvotes,
            :color,
            :text_color
          )
        end
        # rubocop:enable Metrics/AbcSize

        def convert_graphql_state_to_legacy_state(state)
          case state
          when 'OPEN'
            'opened'
          when 'CLOSE'
            'closed'
          end
        end
      end
    end
  end
end
