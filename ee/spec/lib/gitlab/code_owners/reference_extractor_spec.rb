# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::ReferenceExtractor, feature_category: :source_code_management do
  let(:text) do
    <<~TXT
    This is a long text that mentions some users.
    @user-1, @user-2 and user@gitlab.org take a walk in the park.
    There they meet @user-4 that was out with other-user@gitlab.org.
    @user-1 thought it was late, so went home straight away not to
    run into some @group @group/nested-on/other-group
    TXT
  end

  subject(:extractor) { described_class.new(text) }

  describe '#emails' do
    it 'includes all mentioned email addresses' do
      expect(extractor.emails).to contain_exactly('user@gitlab.org', 'other-user@gitlab.org')
    end

    describe "ReDOS vulnerability" do
      subject(:extractor) do
        described_class.new(text + email)
      end

      context "when valid email length" do
        let(:email) { generate_email(100, 255) }

        it "includes the email" do
          expect(extractor.emails).to include(email)
        end
      end

      context "when invalid email first part length" do
        let(:email) { generate_email(101, 255) }

        it "doesn't include the email" do
          expect(extractor.emails).not_to include(email)
        end
      end

      context "when invalid email second part length" do
        let(:email) { generate_email(100, 256) }

        it "doesn't include the email" do
          expect(extractor.emails).not_to include(email)
        end
      end
    end
  end

  describe '#names' do
    it 'includes all mentioned usernames and groupnames' do
      expect(extractor.names).to contain_exactly(
        'user-1', 'user-2', 'user-4', 'group', 'group/nested-on/other-group'
      )
    end
  end

  describe '#references' do
    it 'includes all user-references once' do
      expect(extractor.references).to contain_exactly(
        'user-1', 'user-2', 'user@gitlab.org', 'user-4',
        'other-user@gitlab.org', 'group', 'group/nested-on/other-group'
      )
    end
  end

  def generate_email(left_length, right_length)
    "#{SecureRandom.alphanumeric(left_length)}@#{SecureRandom.alphanumeric(right_length)}"
  end
end
