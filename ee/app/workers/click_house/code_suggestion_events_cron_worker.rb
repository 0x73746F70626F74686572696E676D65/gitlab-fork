# frozen_string_literal: true

module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- this file will be removed in next deploy.
  # Alias worker class for 1 deploy so scheduled cron jobs can work-off properly
  class CodeSuggestionEventsCronWorker < DumpAllWriteBuffersCronWorker
    idempotent!
  end
end
