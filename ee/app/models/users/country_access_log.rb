# frozen_string_literal: true

module Users
  class CountryAccessLog < ::ApplicationRecord
    COUNTRY_CODES = { CN: 0, HK: 1, MO: 2 }.stringify_keys

    enum country_code: COUNTRY_CODES

    belongs_to :user

    validates_uniqueness_of :user_id, scope: :country_code
    validates :access_count, numericality: { greater_than_or_equal_to: 0 }, presence: true
    validates :first_access_at, presence: true, if: -> { access_count.try(:>, 0) }
    validates :last_access_at, presence: true, if: -> { access_count.try(:>, 0) }
  end
end
