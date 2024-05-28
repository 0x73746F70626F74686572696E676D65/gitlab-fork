import { GlCard, GlTable, GlButton, GlFormInput, GlFormGroup } from '@gitlab/ui';
import WorkspaceVariables from 'ee/workspaces/user/components/workspace_variables.vue';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper, mountExtended } from 'helpers/vue_test_utils_helper';
import { WORKSPACE_VARIABLE_INPUT_TYPE_ENUM } from 'ee/workspaces/user/constants';

describe('workspaces/user/components/workspace_variables.vue', () => {
  let wrapper;
  let mockApollo;

  const buildMockApollo = () => {
    mockApollo = createMockApollo([]);
  };

  const GlFormGroupStub = stubComponent(GlFormGroup, {
    props: {
      ...GlFormGroup.props,
      state: {
        type: Boolean,
        required: false,
        default: undefined,
      },
    },
  });

  const buildWrapper = ({ mountFn = mountExtended, variables, showValidations = false } = {}) => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mountFn(WorkspaceVariables, {
      apolloProvider: mockApollo,
      propsData: {
        variables,
        showValidations,
      },
      stubs: {
        GlTable,
        GlCard,
        GlButton,
        GlFormInput,
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  const findCard = () => extendedWrapper(wrapper.findComponent(GlCard));
  const findTable = () => extendedWrapper(wrapper.findComponent(GlTable));
  const findAddButton = () =>
    extendedWrapper(wrapper.findByRole('button', { name: /Add variable/i }));

  beforeEach(() => {
    buildMockApollo();
  });

  it('renders table with empty state', () => {
    const variables = [];
    buildWrapper({ variables });
    expect(findCard().props()).toMatchObject({
      bodyClass: expect.stringContaining('gl-new-card-body'),
      footerClass: expect.stringContaining(''),
      headerClass: expect.stringContaining(''),
    });
    expect(findCard().text()).toContain('Variables');
    expect(findTable().text()).toContain('No variables');
    expect(findAddButton().exists()).toBe(true);
  });

  it('renders table with variables', () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: 'bar2',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    const keys = wrapper.findAllByTestId('key');
    const values = wrapper.findAllByTestId('value');
    const removeButtons = wrapper.findAllByTestId('remove-variable');
    variables.forEach((variable, index) => {
      expect(keys.at(index).element.value).toBe(variable.key);
      expect(values.at(index).element.value).toBe(variable.value);
      expect(removeButtons.at(index).exists()).toBe(true);
    });
  });

  it('adds a new variable', () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    findAddButton().vm.$emit('click');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.addVariable).toHaveLength(1);
    expect(emittedEvents.input).toMatchObject([
      [[...variables, { key: '', value: '', valid: false }]],
    ]);
  });

  it('removes a variable', () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: 'bar2',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo3',
        value: 'bar3',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    wrapper.findAllByTestId('remove-variable').at(1).vm.$emit('click');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...variables.toSpliced(1, 1)]]]);
  });

  it('updates a variable key', async () => {
    const variables = [
      {
        key: '',
        value: '',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    const expectedVariables = [
      {
        key: 'foo1',
        value: '',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: true,
      },
    ];
    buildWrapper({ variables });

    const keys = wrapper.findAllByTestId('key');
    await keys.at(0).vm.$emit('input', 'foo1');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...expectedVariables]]]);
  });

  it('updates a variable value', async () => {
    const variables = [
      {
        key: '',
        value: '',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    const expectedVariables = [
      {
        key: '',
        value: 'bar1',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    const values = wrapper.findAllByTestId('value');
    await values.at(0).vm.$emit('input', 'bar1');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...expectedVariables]]]);
  });

  it('shows validations', () => {
    const variables = [
      {
        key: '',
        value: '',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: '',
        type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: true,
      },
    ];
    const showValidations = true;
    buildWrapper({ variables, showValidations });

    variables.forEach((variable, index) => {
      const row = findTable().findAll('tbody tr').at(index);
      const formGroups = row.findAllComponents(GlFormGroupStub);
      const [keyFormGroup, valueFormGroup] = formGroups.wrappers;

      expect(keyFormGroup.props().state).toBe(variable.valid);
      // Value form group is not validated
      expect(valueFormGroup.props().state).toBe(undefined);
    });
  });
});
