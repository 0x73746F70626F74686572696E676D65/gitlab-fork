# frozen_string_literal: true

module TrialRegistrationsHelper
  TRUSTED_BY_LOGOS = [
    {
      path: 'marketing/t-mobile.svg',
      alt: 'T-Mobile',
      title: 'T-Mobile'
    },
    {
      path: 'marketing/goldman-sachs.svg',
      alt: 'Goldman Sachs',
      title: 'Goldman Sachs'
    },
    {
      path: 'marketing/cncf.svg',
      alt: 'Cloud Native Computing Foundation',
      title: 'Cloud Native Computing Foundation'
    },
    {
      path: 'illustrations/third-party-logos/siemens.svg',
      alt: 'Siemens',
      title: 'Siemens'
    },
    {
      path: 'marketing/nvidia.svg',
      alt: 'NVIDIA',
      title: 'NVIDIA'
    },
    {
      path: 'marketing/ubs.svg',
      alt: 'UBS',
      title: 'UBS'
    }
  ].freeze

  def social_signin_enabled?
    ::Gitlab.com? &&
      omniauth_enabled? &&
      devise_mapping.omniauthable? &&
      button_based_providers_enabled?
  end
end
