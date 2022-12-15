# frozen_string_literal: true

module Slack
  module BlockKit
    module IncidentManagement
      class IncidentModalOpened
        def initialize(projects, response_url)
          @projects = projects
          @response_url = response_url
        end

        def build
          {
            "type": "modal",
            "title": modal_title,
            "submit": submit_button,
            "close": close_button,
            "notify_on_close": true,
            "callback_id": 'incident_modal',
            "private_metadata": response_url,
            "blocks": [
              title_block,
              details_selection_block,
              status_and_assignee_block,
              confidential_block,
              incident_description_block,
              zoom_link_block
            ]
          }
        end

        private

        attr_reader :projects, :response_url

        def modal_title
          {
            "type": "plain_text",
            "text": _("New incident")
          }
        end

        def submit_button
          {
            "type": "plain_text",
            "text": _("Create")
          }
        end

        def close_button
          {
            "type": "plain_text",
            "text": _("Cancel")
          }
        end

        def title_block
          {
            "type": "input",
            "block_id": "title_input",
            "label": {
              "type": "plain_text",
              "text": _("Title")
            },
            "element": {
              "type": "plain_text_input",
              "action_id": "title",
              "placeholder": {
                "type": "plain_text",
                "text": _("Incident title")
              },
              "focus_on_load": true
            }
          }
        end

        def project_selection
          {
            "type": "static_select",
            "action_id": "project",
            "placeholder": {
              "type": "plain_text",
              "text": _("Select project")
            },
            "options": construct_project_selector,
            "initial_option": project_selector_option(projects.first)
          }
        end

        def status_selection
          {
            "type": "static_select",
            "action_id": "status",
            "placeholder": {
              "type": "plain_text",
              "text": s_("Status (optional)")
            },
            "options": [
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("EscalationStatus|Triggered")
                },
                "value": "triggered"
              },
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("EscalationStatus|Acknowledged")
                },
                "value": "acknowledged"
              },
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("EscalationStatus|Resolved")
                },
                "value": "resolved"
              }
            ]
          }
        end

        def severity_selection
          {
            "type": "static_select",
            "action_id": "severity",
            "placeholder": {
              "type": "plain_text",
              "text": s_("Select severity (optional)")
            },
            "options": [
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("Critical - S1")
                },
                "value": "critical"
              },
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("High - S2")
                },
                "value": "high"
              },
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("Medium - S3")
                },
                "value": "medium"
              },
              {
                "text": {
                  "type": "plain_text",
                  "text": s_("Low - S4")
                },
                "value": "low"
              }
            ]
          }
        end

        def confidential_block
          {
            "type": "actions",
            "block_id": "confidentiality",
            "elements": [
              {
                "type": "checkboxes",
                "action_id": "confidential",
                "options": [
                  {
                    "value": "confidential",
                    "text": {
                      "type": "plain_text",
                      "text": _("Confidential")
                    }
                  }
                ]
              }
            ]
          }
        end

        def details_selection_block
          {
            "type": "actions",
            "block_id": "project_and_severity_selector",
            "elements": [
              project_selection,
              severity_selection
            ]
          }
        end

        def status_and_assignee_block
          {
            "type": "actions",
            "block_id": "status_and_assignee_selector",
            "elements": [
              status_selection
            ]
          }
        end

        def incident_description_block
          {
            "block_id": "incident_description",
            "type": "input",
            "element": {
              "type": "plain_text_input",
              "multiline": true,
              "action_id": "description",
              "placeholder": {
                "type": "plain_text",
                "text": [
                  _("Write a description..."),
                  _("[Supports GitLab-flavored markdown, including quick actions]")
                ].join("\n\n")
              }
            },
            "label": {
              "type": "plain_text",
              "text": _("Description")
            }
          }
        end

        def zoom_link_block
          {
            "type": "input",
            "block_id": "zoom",
            "optional": true,
            "element": {
              "type": "plain_text_input",
              "action_id": "link",
              "placeholder": {
                "type": "plain_text",
                "text": format(_("%{url} (optional)"), url: 'https://example.zoom.us')
              }
            },
            "label": {
              "type": "plain_text",
              "text": "Zoom"
            }
          }
        end

        def construct_project_selector
          projects.map do |project|
            project_selector_option(project)
          end
        end

        def project_selector_option(project)
          {
            "text": {
              "type": "plain_text",
              "text": project.full_path
            },
            "value": project.id.to_s
          }
        end
      end
    end
  end
end
