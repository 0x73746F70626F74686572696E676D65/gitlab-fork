# frozen_string_literal: true

FactoryBot.define do
  factory :xray_report, class: 'Projects::XrayReport' do
    project
    lang { 'Ruby' }
    file_checksum { '53b5964d32d30fc60089fb54cd73538003a487afdd5d6a3b549ae162ce4819cd' }
    payload do
      {
        "scannerVersion" => "0.0.1",
        "fileName" => "pyproject.toml",
        "checksum" => "53b5964d32d30fc60089fb54cd73538003a487afdd5d6a3b549ae162ce4819cd",
        "libs" =>
          [
            {
              "name" => "python ~3.9",
              "description" => "Python is a popular general-purpose programming language used for web development."
            },
            {
              "name" => "uvicorn ^0.20.0",
              "description" => "Uvicorn is a lightning-fast ASGI server implementation for Python."
            }
          ]
      }.to_json
    end
  end
end
