# frozen_string_literal: true

module GitlabSubscriptions
  class CreateCompanyLeadService
    def initialize(user:, params:)
      @user = user
      merged_params = params.merge(hardcoded_values).merge(user_values)
      @params = remapping_for_api(merged_params)
    end

    def execute
      build_product_interaction

      GitlabSubscriptions::CreateLeadService.new.execute(
        @params.merge(product_interaction: @product_interaction)
      )
    end

    private

    attr_reader :user

    def hardcoded_values
      {
        provider: 'gitlab',
        skip_email_confirmation: true,
        gitlab_com_trial: true
      }
    end

    def user_values
      {
        uid: user.id,
        work_email: user.email,
        setup_for_company: user.setup_for_company,
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in
      }
    end

    def remapping_for_api(params)
      params[:jtbd] = params.delete(:registration_objective)
      params[:comment] ||= params.delete(:jobs_to_be_done_other)
      params
    end

    def build_product_interaction
      @product_interaction = ::Onboarding::Status.new(@params, nil, user).company_lead_product_interaction
    end
  end
end
