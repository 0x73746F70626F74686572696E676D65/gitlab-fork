# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::GitlabCom::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    let_it_be(:cs_cut_off_date) { Time.zone.parse("2024-02-15 00:00:00 UTC").utc }
    let_it_be(:cs_unit_primitives) { [:code_suggestions] }
    let_it_be(:cs_bundled_with) { { "code_suggestions" => cs_unit_primitives } }

    let_it_be(:duo_chat_unit_primitives) { [:duo_chat, :documentation_search] }
    let_it_be(:duo_chat_bundled_with) { { "code_suggestions" => duo_chat_unit_primitives } }
    let_it_be(:backend) { 'gitlab-ai-gateway' }

    include_examples 'access data reader' do
      let_it_be(:available_service_data_class) { CloudConnector::GitlabCom::AvailableServiceData }
      let_it_be(:arguments_map) do
        {
          code_suggestions: [cs_cut_off_date, cs_bundled_with, backend],
          duo_chat: [nil, duo_chat_bundled_with, backend]
        }
      end
    end
  end
end
