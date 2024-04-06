# frozen_string_literal: true

module RemoteDevelopment
  module RailwayOrientedProgrammingHelpers
    # NOTE: Depends upon `value` being defined in the including spec
    def stub_methods_to_return_ok_result(*methods)
      methods.each do |method|
        allow(method).to receive(:call).with(value) { Result.ok(value) }
      end
    end

    # NOTE: Depends upon `value` and `err_message_context` being defined in the including spec
    def stub_methods_to_return_err_result(method:, message_class:)
      allow(method).to receive(:call).with(value) do
        Result.err(message_class.new(err_message_context))
      end
    end

    def stub_methods_to_return_value(*methods)
      methods.each do |method|
        allow(method).to receive(:call).with(value) { value }
      end
    end

    def stub_method_to_modify_and_return_value(method, expected_value:, returned_value:)
      allow(method).to receive(:call).with(expected_value) { returned_value }
    end
  end
end
