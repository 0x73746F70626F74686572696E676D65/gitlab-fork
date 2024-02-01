# frozen_string_literal: true

module Pajamas
  class SingleStatComponent < Pajamas::Component
    # @param [String] title
    # @param [String] stat_value
    # @param [String] unit
    # @param [String] title_icon
    # @param [String] meta_text
    # @param [String] meta_icon
    # @param [Symbol] variant
    def initialize(
      title: nil,
      stat_value: nil,
      unit: nil,
      title_icon: nil,
      meta_text: nil,
      meta_icon: nil,
      text_color: nil,
      variant: :muted
    )
      @title = title
      @stat_value = stat_value
      @unit = unit
      @title_icon = title_icon.to_s.presence
      @meta_text = meta_text
      @meta_icon = meta_icon
      @text_color = text_color
      @variant = filter_attribute(variant.to_sym, Pajamas::BadgeComponent::VARIANT_OPTIONS, default: :muted)
    end

    private

    delegate :sprite_icon, to: :helpers

    def unit_class
      "gl-mr-2" unless unit?
    end

    def unit?
      @unit
    end

    def title_icon?
      @title_icon
    end

    def meta_icon?
      @meta_icon
    end

    def meta_text?
      @meta_text
    end
  end
end
