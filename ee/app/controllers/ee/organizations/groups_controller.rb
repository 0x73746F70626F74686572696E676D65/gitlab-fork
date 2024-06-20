# frozen_string_literal: true

module EE
  module Organizations
    module GroupsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action :check_subscription!, only: [:destroy]
      end

      override :destroy
      def destroy
        return super unless group.adjourned_deletion?

        if group.marked_for_deletion? &&
            ::Gitlab::Utils.to_boolean(params.permit(:permanently_remove)[:permanently_remove])
          return super
        end

        result = ::Groups::MarkForDeletionService.new(group, current_user).execute

        if result[:status] == :success
          removal_time = permanent_deletion_date_formatted(group, Time.current.utc)
          message = _("'%{group_name}' has been scheduled for removal on %{removal_time}.")

          render json: { message: format(message, group_name: group.name, removal_time: removal_time) }
        else
          render json: { message: result[:message] }, status: :unprocessable_entity
        end
      end

      private

      def check_subscription!
        return unless group.prevent_delete?

        render json: { message: _('This group is linked to a subscription') }, status: :bad_request
      end
    end
  end
end
