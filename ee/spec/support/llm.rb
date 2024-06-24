# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :real_ai_request) do |example|
    real_ai_request_bool = ActiveModel::Type::Boolean.new.cast(ENV['REAL_AI_REQUEST'])

    if !real_ai_request_bool || !ENV['ANTHROPIC_API_KEY']
      puts "skipping '#{example.description}' because it does real third-party requests, set " \
           "REAL_AI_REQUEST=true, ANTHROPIC_API_KEY='<key>'"
      next
    end

    with_net_connect_allowed do
      example.run
    end
  end

  config.before(:each, :real_ai_request) do
    allow(Gitlab::CurrentSettings.current_application_settings).to receive(:anthropic_api_key)
      .at_least(:once).and_return(ENV['ANTHROPIC_API_KEY'])
  end
end
