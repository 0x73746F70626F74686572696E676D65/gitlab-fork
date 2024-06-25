# frozen_string_literal: true

module Gitlab
  module SidekiqMiddleware
    module SetSession
      class Server
        def call(_worker, job, _queue)
          if job.key?('set_session_id')
            session_id = job['set_session_id']
            session = ActiveSession.sessions_from_ids([job['set_session_id']]).first if session_id
            session ||= {}
            session = session.with_indifferent_access

            ::Gitlab::Session.with_session(session) do
              yield
            end
          else
            yield
          end
        end
      end
    end
  end
end
