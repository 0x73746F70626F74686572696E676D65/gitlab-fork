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
  end

  describe '#current_page_short_description' do
    it 'returns prompt' do
      expect(wrapped_issue.current_page_short_description).to include("The title of the issue is '#{issue.title}'.")
      expect(wrapped_issue.current_page_short_description)
        .not_to include("utilize it instead of using the 'IssueReader' tool")
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_issue.current_page_type).to eq('issue')
    end
  end
end
