# frozen_string_literal: true

module Billing
  class PlanComponent < ViewComponent::Base
    # @param [Namespace or Group] namespace
    # @param [Hashie::Mash] plan
    # @param [Hashie::Mash] current_plan

    def initialize(plan:, namespace:, current_plan:)
      @plan = plan.merge(plans_data.fetch(plan.code, {}))
      @namespace = namespace
      @current_plan = current_plan
    end

    # JH need override the symbol
    def currency_symbol
      "$"
    end

    private

    attr_reader :plan, :namespace, :current_plan

    delegate :number_to_plan_currency, :plan_purchase_url, to: :helpers
    delegate :sprite_icon, to: :helpers

    def render?
      plans_data.key?(plan.code)
    end

    def free?
      plan.free
    end

    def trial?
      current_plan.code == ::Plan::ULTIMATE_TRIAL
    end

    def card_classes
      "gl-text-left gl-mt-7 gl-mr-7 gl-border-none billing-plan-card"
    end

    def card_testid
      "plan-card-#{plan.code}"
    end

    def header_classes
      return "gl-border-none gl-bg-transparent gl-p-0 gl-h-0\!" if trial?

      "gl-text-center gl-border-none gl-p-0 gl-leading-28 #{plan.header_classes}"
    end

    def header_text
      return if trial?

      plan.header_text
    end

    def body_classes
      base = "gl-bg-gray-10 gl-p-7 gl-border"

      return "#{base} gl-rounded-base" if trial?

      "#{base} gl-rounded-bottom-right-base gl-rounded-bottom-left-base " \
        "#{plan.card_body_border_classes}"
    end

    def footer_classes
      "gl-border-none gl-bg-transparent gl-px-0"
    end

    def name
      plan_name = "BillingPlans|#{plan.code.capitalize}"
      s_(plan_name)
    end

    def elevator_pitch
      plan.elevator_pitch
    end

    def features_elevator_pitch
      plan.features_elevator_pitch
    end

    def learn_more_text
      "Learn more about #{plan.code.capitalize}"
    end

    def learn_more_url
      "https://about.gitlab.com/pricing/#{plan.code}"
    end

    def price_per_month
      number_to_currency(plan.price_per_month, unit: '', strip_insignificant_zeros: true)
    end

    def annual_price_text
      s_("BillingPlans|Billed annually at %{price_per_year} USD") % { price_per_year: price_per_year }
    end

    def price_per_year
      number_to_plan_currency(plan.price_per_year)
    end

    def cta_text
      plan.fetch(:cta_text, s_("BillingPlans|Upgrade"))
    end

    def cta_url
      plan_purchase_url(namespace, plan)
    end

    def cta_category
      trial? ? plan.cta_category.trial : plan.cta_category.free
    end

    def cta_data
      {
        track_action: 'click_button',
        track_label: 'plan_cta',
        track_property: plan.code
      }.merge(plan.fetch(:cta_data, {}))
    end

    def features
      plan.features
    end

    def plans_data
      {
        'free' => {
          header_text: s_("BillingPlans|Your current plan"),
          header_classes: "gl-bg-gray-100",
          elevator_pitch: s_("BillingPlans|Use GitLab for personal projects"),
          features_elevator_pitch: s_("BillingPlans|Free forever features:"),
          features: [
            {
              title: s_("BillingPlans|5GB storage")
            },
            {
              title: s_("BillingPlans|10GB transfer per month")
            },
            {
              title: s_("BillingPlans|400 CI/CD minutes per month")
            },
            {
              title: s_("BillingPlans|5 users per top-level group")
            }
          ]
        },
        'premium' => {
          card_body_border_classes: "gl-border-purple-500\!",
          header_text: s_("BillingPlans|Recommended"),
          header_classes: "gl-text-white gl-bg-purple-500",
          elevator_pitch: s_("BillingPlans|For scaling organizations and multi-team usage"),
          features_elevator_pitch: s_("BillingPlans|Everything from Free, plus:"),
          features: [
            {
              title: s_("BillingPlans|Code Ownership and Protected Branches")
            },
            {
              title: s_("BillingPlans|Merge Request Approval Rules")
            },
            {
              title: s_("BillingPlans|Enterprise Agile Planning")
            },
            {
              title: s_("BillingPlans|Advanced CI/CD")
            },
            {
              title: s_("BillingPlans|Support")
            },
            {
              title: s_("BillingPlans|Enterprise User and Incident Management")
            },
            {
              title: s_("BillingPlans|50GB storage")
            },
            {
              title: s_("BillingPlans|100GB transfer per month")
            },
            {
              title: s_("BillingPlans|10,000 CI/CD minutes per month")
            }
          ],
          cta_text: s_("BillingPlans|Upgrade to Premium"),
          cta_category: {
            free: "primary",
            trial: 'secondary'
          },
          cta_data: {
            testid: "upgrade-to-premium"
          }
        },
        'ultimate' => {
          header_classes: "gl-bg-transparent",
          card_body_border_classes: "gl-rounded-top-right-base gl-rounded-top-left-base",
          elevator_pitch: s_("BillingPlans|For enterprises looking to deliver software faster"),
          features_elevator_pitch: s_("BillingPlans|Everything from Premium, plus:"),
          features: [
            {
              title: s_("BillingPlans|Suggested Reviewers")
            },
            {
              title: s_("BillingPlans|Dynamic Application Security Testing")
            },
            {
              title: s_("BillingPlans|Security Dashboards")
            },
            {
              title: s_("BillingPlans|Vulnerability Management")
            },
            {
              title: s_("BillingPlans|Dependency Scanning")
            },
            {
              title: s_("BillingPlans|Container Scanning")
            },
            {
              title: s_("BillingPlans|Static Application Security Testing")
            },
            {
              title: s_("BillingPlans|Multi-Level Epics")
            },
            {
              title: s_("BillingPlans|Portfolio Management")
            },
            {
              title: s_("BillingPlans|Custom Roles")
            },
            {
              title: s_("BillingPlans|Value Stream Management")
            },
            {
              title: s_("BillingPlans|250GB storage")
            },
            {
              title: s_("BillingPlans|500GB transfer per month")
            },
            {
              title: s_("BillingPlans|50,000 CI/CD minutes per month")
            },
            {
              title: s_("BillingPlans|Free guest users")
            }
          ],
          cta_text: s_("BillingPlans|Upgrade to Ultimate"),
          cta_category: {
            free: "secondary",
            trial: 'primary'
          },
          cta_data: {
            testid: "upgrade-to-ultimate"
          }
        }
      }
    end
  end
end

Billing::PlanComponent.prepend_mod
