# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class BackfillIssueEmbeddings
        def self.execute(project_id:)
          issues_to_backfill = Project.find(project_id).issues

          puts "Adding #{issues_to_backfill.count} issue embeddings to the queue"

          issues_to_backfill.each_batch do |batch|
            batch.each do |issue|
              ::Search::Elastic::ProcessEmbeddingBookkeepingService.track_embedding!(issue)
            end
          end

          while ::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size > 0
            puts "Queue size: #{::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size}"

            ::Search::Elastic::ProcessEmbeddingBookkeepingService.new.execute

            if ::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size > 0
              puts 'Sleeping for 1 minute...'
              sleep(60)
            end
          end

          puts "Finished processing the queue.\nAll issues for project (#{project_id}) now have embeddings."
        end
      end
    end
  end
end
