# frozen_string_literal: true
module GitlabSubscriptions
  class CreateTrialOrLeadService
    def initialize(user:, params:)
      @params = params.merge(hardcoded_values).merge(user_values(user))
      @generate_trial = Gitlab::Utils.to_boolean(params[:trial])
    end

    def execute
      response = submit_client_request(@params, generate_trial: @generate_trial)

      if response[:success]
        ServiceResponse.success
      else
        ServiceResponse.error(message: response.dig(:data, :errors), http_status: :unprocessable_entity)
      end
    end

    private

    def hardcoded_values
      {
        provider: 'gitlab',
        skip_email_confirmation: true,
        gitlab_com_trial: true
      }
    end

    def user_values(user)
      {
        uid: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        work_email: user.email,
        setup_for_company: user.setup_for_company,
        newsletter_segment: user.email_opted_in
      }
    end

    def submit_client_request(params, generate_trial: false)
      if generate_trial
        client.generate_trial(trial_user: params)
      else
        client.generate_hand_raise_lead(params)
      end
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end
  end
end
