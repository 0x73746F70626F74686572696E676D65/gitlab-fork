# frozen_string_literal: true

module Pajamas
  class BroadcastBannerComponent < Pajamas::Component
    # @param [String] message
    # @param [String] id
    # @param [String] theme
    # @param [Boolean] dismissable
    # @param [String] expire_date
    # @param [String] cookie_key
    # @param [String] dismissal_path
    def initialize(message:, id:, theme:, dismissable:, expire_date:, cookie_key:, dismissal_path: nil)
      @message = message
      @id = id
      @theme = theme
      @dismissable = dismissable
      @expire_date = expire_date
      @cookie_key = cookie_key
      @dismissal_path = dismissal_path
    end

    delegate :sprite_icon, to: :helpers
  end
end
