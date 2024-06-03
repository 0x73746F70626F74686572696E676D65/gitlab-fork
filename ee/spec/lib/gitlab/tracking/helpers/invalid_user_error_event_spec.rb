# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::Helpers::InvalidUserErrorEvent, feature_category: :activation do
  let(:user) { build(:user) }

  subject(:helper) { Class.new.include(described_class).new }

  context 'when user has a weak password error' do
    before do
      user.password = 'password'
      user.valid?
    end

    it 'tracks the event' do
      helper.track_invalid_user_error(user, 'free_registration')

      expect_snowplow_event(
        category: 'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
        action: 'track_free_registration_error',
        label: 'password_must_not_contain_commonly_used_combinations_of_words_and_letters'
      )
    end
  end

  context 'when user does not have any errors' do
    it 'does not track the event' do
      helper.track_invalid_user_error(user, 'free_registration')

      expect_no_snowplow_event
    end
  end
end
