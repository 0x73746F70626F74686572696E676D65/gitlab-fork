# frozen_string_literal: true

module Gitlab
  module GithubImport
    module Importer
      module Events
        class ChangedLabel < BaseImporter
          def execute(issue_event)
            create_event(issue_event)
          end

          private

          def create_event(issue_event)
            ResourceLabelEvent.create!(
              issue_id: issuable_db_id(issue_event),
              user_id: author_id(issue_event),
              label_id: label_finder.id_for(issue_event.label_title),
              action: action(issue_event.event),
              created_at: issue_event.created_at
            )
          end

          def label_finder
            Gitlab::GithubImport::LabelFinder.new(project)
          end

          def action(event_type)
            event_type == 'unlabeled' ? 'remove' : 'add'
          end
        end
      end
    end
  end
end
