# frozen_string_literal: true

module GitlabSubscriptions
  module DuoPro
    def self.add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder.new(namespace).execute.first
    end

    def self.any_add_on_purchase_for_namespace_id(namespace_id)
      GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.by_namespace_id(namespace_id).first
    end

    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder.new(namespace, only_active: false).execute.first
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder.new(namespace, only_active: false).execute.none?
    end

    def self.no_active_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder.new(namespace).execute.none?
    end
  end
end
