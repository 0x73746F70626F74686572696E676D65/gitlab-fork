# frozen_string_literal: true

module CloudConnector
  # This class can be used as a drop-in for AvailableServiceData in order to
  # prevent access to CloudConnector services if access data is missing.
  class MissingServiceData
    def name
      :missing_service
    end

    def free_access?
      false
    end

    def allowed_for?(_user)
      false
    end

    def purchased?(_namespace = nil)
      false
    end

    def access_token(_resource = nil, **)
      nil
    end
  end
end
