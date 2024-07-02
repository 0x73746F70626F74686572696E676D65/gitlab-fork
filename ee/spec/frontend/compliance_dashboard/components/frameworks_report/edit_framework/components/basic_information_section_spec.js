import * as Utils from 'ee/groups/settings/compliance_frameworks/utils';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/basic_information_section.vue';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

describe('Basic information section', () => {
  let wrapper;
  const fakeFramework = {
    id: '1',
    name: 'Foo',
    description: 'Bar',
    pipelineConfigurationFullPath: null,
    color: null,
  };

  const defaultProvides = {
    featurePipelineMaintenanceModeEnabled: true,
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    pipelineExecutionPolicyPath: '/policypath',
  };

  const invalidFeedback = (input) =>
    input.closest('[role=group].is-invalid').querySelector('.invalid-feedback').textContent;

  function createComponent(props, provides) {
    return mountExtended(BasicInformationSection, {
      provide: {
        ...defaultProvides,
        ...provides,
      },
      propsData: {
        value: fakeFramework,
        ...props,
      },
      stubs: {
        ColorPicker: true,
      },
    });
  }
  const findMaintenanceAlert = () => wrapper.findComponentByTestId('maintenance-mode-alert');

  beforeEach(() => {
    wrapper = createComponent();
  });

  it.each([['Name'], ['Description']])(
    'validates required state for field %s',
    async (fieldName) => {
      const input = wrapper.findByLabelText(fieldName);
      await input.setValue('');

      expect(invalidFeedback(input.element)).toContain('is required');

      expect(wrapper.emitted('valid').at(-1)).toStrictEqual([false]);
    },
  );

  it.each`
    pipelineConfigurationFullPath | message
    ${'foo.yml@bar/baz'}          | ${'Configuration not found'}
    ${'foobar'}                   | ${'Invalid format'}
  `(
    'sets the correct invalid message for pipeline',
    async ({ pipelineConfigurationFullPath, message }) => {
      jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);

      const pipelineInput = wrapper.findByLabelText('Compliance pipeline configuration (optional)');
      await pipelineInput.setValue(pipelineConfigurationFullPath);
      await waitForPromises();

      expect(invalidFeedback(pipelineInput.element)).toBe(message);
    },
  );

  it('renders section as initially expanded if expandable', () => {
    wrapper = createComponent({ expandable: true });

    expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(true);
  });

  it('renders the maintenance-mode-alert', () => {
    const maintenanceAlert = findMaintenanceAlert();

    expect(maintenanceAlert.exists()).toBe(true);
    expect(maintenanceAlert.text()).toContain('Compliance pipelines are deprecated');
  });

  describe('when ff_compliance_pipeline_maintenance_mode feature flag is disabled', () => {
    it('does not render the maintenance-mode-alert', () => {
      wrapper = createComponent({}, { featurePipelineMaintenanceModeEnabled: false });
      const maintenanceAlert = findMaintenanceAlert();

      expect(maintenanceAlert.exists()).toBe(false);
    });
  });
});
