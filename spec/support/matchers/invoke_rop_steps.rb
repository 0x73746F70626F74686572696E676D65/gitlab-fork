# frozen_string_literal: true

module InvokeRopSteps
  private

  def public_methods_to_ignore
    # Singleton methods to exist on class objects by default that we need to ignore.
    [:yaml_tag, :method]
  end

  def add_err_result_for_step(err_result_for_step, err_results_for_steps)
    result_type = :err
    step_class, returned_message = parse_result_for_step(err_result_for_step, result_type)

    err_results_for_steps[step_class] = Result.err(returned_message)
  end

  def add_ok_result_for_step(ok_result_for_step, ok_results_for_steps)
    result_type = :ok
    step_class, returned_message = parse_result_for_step(ok_result_for_step, result_type)

    ok_results_for_steps[step_class] = Result.ok(returned_message)
  end

  def parse_result_for_step(result_for_step, result_type)
    unless result_for_step[:step_class].is_a?(Class)
      raise "'with_#{result_type}_result_for_step' argument entry 'step_class' be of type 'Class'"
    end

    unless result_for_step[:returned_message].is_a?(RemoteDevelopment::Message)
      raise "'with_#{result_type}_result_for_step' argument entry 'returned_message' be a subclass of " \
        "'RemoteDevelopment::Messages'"
    end

    result_for_step => {
      step_class: Class => step_class,
      returned_message: RemoteDevelopment::Message => returned_message
    }

    [step_class, returned_message]
  end

  def validate_rop_steps(rop_steps)
    raise "'invoke_rop_steps' argument must be an Array, but was a #{rop_steps.class}" unless rop_steps.is_a?(Array)

    rop_steps.each do |expected_rop_step|
      unless expected_rop_step.is_a?(Array)
        raise "'invoke_rop_steps' argument array entry must be an Array, but was a #{expected_rop_step.class}"
      end

      unless expected_rop_step.size == 2
        raise "'invoke_rop_steps' argument array entry must be an Array of size 2, " \
          "but was an Array of size #{expected_rop_step.size}"
      end

      step_class = expected_rop_step[0]
      unless step_class.is_a?(Class)
        raise "'invoke_rop_steps' argument array entry first element '#{step_class}' must be a Class " \
          "representing a step class, but was a #{step_class.class}"
      end

      step_action = expected_rop_step[1]
      unless step_action.is_a?(Symbol)
        raise "'invoke_rop_steps' argument array entry second element '#{step_action}' must be a Symbol, " \
          "but was a #{step_action.class}"
      end

      unless [:map, :and_then].freeze.include?(step_action)
        raise "'invoke_rop_steps' argument array entry second element ':#{step_action}' must be either " \
          ":map or :and_then, but was :#{step_action}"
      end
    end
  end

  def validate_main_class(main_class)
    raise "'main_class' argument must be a Class, but was a #{main_class.class}" unless main_class.is_a?(Class)
  end

  def validate_main_class_was_specified_in_chain(main_class)
    raise "'from_main_class' chain must be specified on all 'invoke_rop_steps' matchers" unless main_class
  end

  def validate_value_passed_along_steps(value)
    raise "'value_passed_along_steps' argument must be a Hash, but was a #{value.class}" unless value.is_a?(Hash)
  end

  def validate_value_passed_along_steps_was_specified_in_chain(value)
    raise "'value_passed_along_steps' chain must be specified on all 'invoke_rop_steps' matchers" unless value
  end

  def validate_expected_return_value(expected_return_value)
    if expected_return_value.is_a?(Hash) || expected_return_value.is_a?(Result) || expected_return_value < RuntimeError
      return
    end

    raise "'and_return_expected_value' argument must be a Hash,Result or a subclass of RuntimeError, " \
      "but was a #{expected_return_value.class}"
  end

  def validate_expected_return_value_matcher_was_specified_in_chain(expected_return_value_matcher)
    return if expected_return_value_matcher

    raise "'and_return_expected_value' chain must be specified on all 'invoke_rop_steps' matchers"
  end

  def build_expected_rop_steps(
    rop_steps:,
    err_results_for_steps:,
    ok_results_for_steps:,
    value_passed_along_steps:
  )

    expected_rop_steps = []

    rop_steps.each do |rop_step|
      step_class = rop_step[0]
      step_action = rop_step[1]
      expected_rop_step = {
        step_class: step_class,
        step_class_method: retrieve_rop_class_method(step_class),
        step_action: step_action
      }

      if err_results_for_steps.key?(step_class)
        expected_rop_step[:returned_object] = err_results_for_steps[step_class]

        # Currently, only a single error step is supported, so we assign expected_rop_step as the last entry
        # in expected_rop_steps, break out of the loop early, and do not add any more steps
        expected_rop_steps << expected_rop_step
        break
      elsif ok_results_for_steps.key?(step_class)
        expected_rop_step[:returned_object] = ok_results_for_steps[step_class]
      elsif step_action == :and_then
        expected_rop_step[:returned_object] = Result.ok(value_passed_along_steps)
      elsif step_action == :map
        expected_rop_step[:returned_object] = value_passed_along_steps
      else
        raise "Unexpected internal error when building expected ROP steps: step_action '#{step_action}' is invalid"
      end

      expected_rop_steps << expected_rop_step
    end

    expected_rop_steps
  end

  def retrieve_rop_class_method(step_class)
    public_methods = step_class.singleton_methods(false).reject { |method| public_methods_to_ignore.include?(method) }

    if public_methods.size != 1
      raise "Pattern violation in class #{step_class}: exactly one public method must be present in an ROP class"
    end

    public_methods.first
  end

  def setup_mock_expectations_for_steps(steps:, value_passed_along_steps:)
    steps.each do |step|
      step => {
        step_class: Class => step_class,
        step_class_method: Symbol => step_class_method,
        returned_object: Result | Hash => returned_object
      }

      set_up_step_class_expectation(
        step_class: step_class,
        step_class_method: step_class_method,
        value_passed_along_steps: value_passed_along_steps,
        returned_object: returned_object
      )
    end
  end

  def set_up_step_class_expectation(
    step_class:,
    step_class_method:,
    value_passed_along_steps:,
    returned_object:
  )
    expect(step_class).to receive(step_class_method).with(value_passed_along_steps).ordered do
      returned_object
    end
  end
end

RSpec::Matchers.define :invoke_rop_steps do |rop_steps|
  include InvokeRopSteps

  supports_block_expectations

  main_class = nil
  value_passed_along_steps = nil
  err_results_for_steps = {}
  ok_results_for_steps = {}
  expected_return_value_matcher = nil
  expected_return_value = nil

  match do |block|
    validate_main_class_was_specified_in_chain(main_class)
    validate_value_passed_along_steps_was_specified_in_chain(value_passed_along_steps)
    validate_expected_return_value_matcher_was_specified_in_chain(expected_return_value_matcher)
    validate_rop_steps(rop_steps)

    steps = build_expected_rop_steps(
      rop_steps: rop_steps,
      err_results_for_steps: err_results_for_steps,
      ok_results_for_steps: ok_results_for_steps,
      value_passed_along_steps: value_passed_along_steps
    )

    setup_mock_expectations_for_steps(
      steps: steps,
      value_passed_along_steps: value_passed_along_steps
    )

    expected_return_value_matcher.call(block)
  end

  chain :from_main_class do |clazz|
    validate_main_class(clazz)
    main_class = clazz
    main_class_method = retrieve_rop_class_method(main_class)
    expect(main_class).to receive(main_class_method).and_call_original
  end

  chain :with_value_passed_along_steps do |value|
    validate_value_passed_along_steps(value)
    # noinspection RubyUnusedLocalVariable -- TODO: open issue and add to https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues
    value_passed_along_steps = value
  end

  chain :with_err_result_for_step do |err_result_for_step|
    # For now, only one 'with_err_result_for_step' is allowed, since our current implementation of
    # Result does not have any support for "*or*" methods which could continue after an
    # error result (e.g. https://doc.rust-lang.org/std/result/enum.Result.html#method.or)
    raise "Only one 'with_err_result_for_step' is allowed" unless err_results_for_steps.empty?

    # noinspection RubyResolve -- TODO: open issue and add to https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues
    add_err_result_for_step(err_result_for_step, err_results_for_steps)
  end

  chain :with_ok_result_for_step do |ok_result_for_step|
    # Even though the OK step is normally only applicable to the last step in a chain, multiple steps
    # are allowed to return OK results for other cases, e.g. if there is a `map` with a lambda in the middle
    # the chain, which performs some processing on the value passed along the chain.
    add_ok_result_for_step(ok_result_for_step, ok_results_for_steps)
  end

  chain :and_return_expected_value do |value|
    validate_expected_return_value(value)
    expected_return_value = value
    expected_return_value_matcher = if value.is_a?(Hash) || value.is_a?(Result)
                                      ->(main) { expect(main.call).to eq(value) }
                                    else
                                      ->(main) { expect { main.call }.to raise_error(value) }
                                    end
  end

  failure_message do |block|
    "expected returned value from #{block} to equal '#{expected_return_value}' " \
      "but was '#{block.call}' instead."
  end
end
