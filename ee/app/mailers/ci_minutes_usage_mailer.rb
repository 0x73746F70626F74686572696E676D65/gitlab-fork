# frozen_string_literal: true

class CiMinutesUsageMailer < ApplicationMailer
  helper EmailsHelper
  helper NamespacesHelper

  layout 'mailer'

  def notify(namespace, recipients)
    @namespace = namespace

    mail_with_locale(
      bcc: recipients,
      subject: "Action required: There are no remaining compute minutes for #{@namespace.name}"
    )
  end

  def notify_limit(namespace, recipients, percentage_of_available_mins)
    @namespace = namespace
    @percentage_of_available_mins = percentage_of_available_mins

    mail_with_locale(
      bcc: recipients,
      subject: "Action required: Less than #{percentage_of_available_mins}% " \
               "of compute minutes remain for #{@namespace.name}"
    )
  end
end
