# frozen_string_literal: true

class IssuesMrsEmptyStateExperiment < ApplicationExperiment
  control
  variant(:candidate)

  private

  def control_behavior; end
  def candidate_behavior; end
end
