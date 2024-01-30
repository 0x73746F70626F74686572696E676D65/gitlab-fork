# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Housekeeper::Change do
  let(:change) { described_class.new }

  before do
    change.title = 'The title'
    change.description = 'The description'
  end

  describe '#mr_description' do
    it 'includes standard content' do
      expect(change.mr_description).to eq(
        <<~MARKDOWN
        The description

        This change was generated by
        [gitlab-housekeeper](https://gitlab.com/gitlab-org/gitlab/-/tree/master/gems/gitlab-housekeeper)
        MARKDOWN
      )
    end
  end

  describe '#commit_message' do
    it 'includes standard content' do
      expect(change.commit_message).to eq(
        <<~MARKDOWN
        The title

        The description

        This change was generated by
        [gitlab-housekeeper](https://gitlab.com/gitlab-org/gitlab/-/tree/master/gems/gitlab-housekeeper)


        Changelog: other
        MARKDOWN
      )
    end
  end

  describe '#valid?' do
    it 'is not valid if missing required attributes' do
      [:identifiers, :title, :description, :changed_files].each do |attribute|
        change = create_change
        expect(change).to be_valid
        change.public_send("#{attribute}=", nil)
        expect(change).not_to be_valid
      end
    end
  end

  describe '#matches_filters?' do
    let(:identifiers) { %w[this-is a-list of IdentifierS] }
    let(:change) { create_change(identifiers: identifiers) }

    it 'matches when all regexes match at least one identifier' do
      expect(change.matches_filters?([/list/, /Ide.*fier/])).to eq(true)
    end

    it 'does not match when none of the regexes match' do
      expect(change.matches_filters?([/nomatch/, /Ide.*fffffier/])).to eq(false)
    end

    it 'does not match when only some of the regexes match' do
      expect(change.matches_filters?([/nomatch/, /Ide.*fier/])).to eq(false)
    end

    it 'matches an empty list of filters' do
      expect(change.matches_filters?([])).to eq(true)
    end
  end
end
