# frozen_string_literal: true

RSpec.shared_context 'with work item types request context EE' do
  include_context 'with work item types request context'

  let(:work_item_type_fields) do
    <<~GRAPHQL
      id
      name
      iconName
      widgetDefinitions {
        type
        ... on WorkItemWidgetDefinitionAssignees {
          canInviteMembers
          allowsMultipleAssignees
        }
        ... on WorkItemWidgetDefinitionHierarchy {
          allowedChildTypes {
            nodes { id name }
          }
          allowedParentTypes {
            nodes { id name }
          }
        }
        ... on WorkItemWidgetDefinitionLabels {
          allowsScopedLabels
        }
      }
    GRAPHQL
  end

  let(:widget_attributes) do
    ee_attributes = {
      assignees: {
        'allowsMultipleAssignees' => true
      },
      labels: {
        'allowsScopedLabels' => false
      }
    }

    base_widget_attributes.deep_merge(ee_attributes)
  end
end
