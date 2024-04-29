# frozen_string_literal: true

RSpec.describe "cng" do
  let(:usage) do
    <<~USAGE
      Commands:
        cng help [COMMAND]  # Describe available commands or one specific command
        cng version         # Prints cng orchestrator version
    USAGE
  end

  it "runs executable" do
    expect(`bundle exec exe/cng`.strip).to eq(usage.strip)
  end
end
