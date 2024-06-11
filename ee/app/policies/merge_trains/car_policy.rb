# frozen_string_literal: true

module MergeTrains
  class CarPolicy < BasePolicy
    delegate { @subject.project }
  end
end
