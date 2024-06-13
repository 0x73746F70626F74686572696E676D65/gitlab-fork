# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class WidgetPresenter < Gitlab::View::Presenter::Simple
      presents ::Namespace, as: :namespace

      def initialize(namespace, user:)
        super

        @widget_presenter = GitlabSubscriptions::Trials::StatusWidgetPresenter.new(namespace) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
      end

      def attributes
        return {} unless eligible?

        presenter.attributes
      end

      private

      attr_reader :widget_presenter

      def eligible?
        eligible_for_widget? && presenter.eligible_for_widget?
      end

      def presenter
        @presenter ||=
          if widget_presenter.eligible_for_widget?
            widget_presenter
          else
            DuoProStatusWidgetPresenter.new(namespace, user: user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
          end
      end

      def eligible_for_widget?
        namespace.present? &&
          ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          Ability.allowed?(user, :admin_namespace, namespace)
      end
    end
  end
end
