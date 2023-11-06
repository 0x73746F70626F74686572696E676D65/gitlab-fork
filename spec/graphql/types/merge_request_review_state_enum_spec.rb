# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MergeRequestReviewState'] do
  it 'the correct enum members' do
    expect(described_class.values).to match(
      'REVIEWED' => have_attributes(
        description: 'Merge request reviewer has reviewed.',
        value: 'reviewed'
      ),
      'UNREVIEWED' => have_attributes(
        description: 'Awaiting review from merge request reviewer.',
        value: 'unreviewed'
      ),
      'REQUESTED_CHANGES' => have_attributes(
        description: 'Merge request reviewer has requested changes.',
        value: 'requested_changes'
      )
    )
  end
end
