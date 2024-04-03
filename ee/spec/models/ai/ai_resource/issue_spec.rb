# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Issue, feature_category: :duo_chat do
  let(:issue) { build(:issue) }
  let(:user) { build(:user) }

  subject(:wrapped_issue) { described_class.new(issue) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(::IssueSerializer).to receive_message_chain(:new, :represent)
                                     .with(current_user: user, project: issue.project)
                                     .with(issue, {
                                       user: user,
                                       notes_limit: 100,
                                       serializer: 'ai',
                                       resource: wrapped_issue
                                     })
      wrapped_issue.serialize_for_ai(user: user, content_limit: 100)
    end
  end

  describe '#current_page_sentence' do
    it 'returns prompt' do
      expect(wrapped_issue.current_page_sentence).to include("utilize it instead of using the 'IssueReader' tool")
    end

    context 'when ai_prompt_current_page_skip_reader is off' do
      it 'returns older prompt' do
        stub_feature_flags(ai_prompt_current_page_skip_reader: false)

        expect(wrapped_issue.current_page_sentence).to include('Here is additional data in <resource></resource>')
      end
    end
  end
end
