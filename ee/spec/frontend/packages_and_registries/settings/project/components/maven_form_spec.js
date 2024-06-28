import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenForm from 'ee_component/packages_and_registries/settings/project/components/maven_form.vue';
import { dependencyProxyPackagesSettingsData } from '../mock_data';

describe('maven form', () => {
  let wrapper;

  const { mavenExternalRegistryUrl, mavenExternalRegistryUsername } =
    dependencyProxyPackagesSettingsData;

  const defaultProps = {
    value: {
      mavenExternalRegistryUrl,
      mavenExternalRegistryUsername,
      mavenExternalRegistryPassword: '',
    },
  };

  const mountComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(MavenForm, {
      propsData: { ...props },
    });
  };

  it('renders header', () => {
    mountComponent();

    expect(wrapper.findByRole('heading', { level: 5, name: 'Maven' }).exists()).toBe(true);
  });

  describe.each`
    index | field                              | label         | description                               | value                            | trimmed
    ${0}  | ${'mavenExternalRegistryUrl'}      | ${'URL'}      | ${'Base URL of the external registry.'}   | ${mavenExternalRegistryUrl}      | ${true}
    ${1}  | ${'mavenExternalRegistryUsername'} | ${'Username'} | ${'Username of the external registry.'}   | ${mavenExternalRegistryUsername} | ${true}
    ${2}  | ${'mavenExternalRegistryPassword'} | ${'Password'} | ${'Password for your external registry.'} | ${''}                            | ${false}
  `('$label', ({ index, field, description, label, value, trimmed }) => {
    let formGroup;
    let formInput;

    beforeEach(() => {
      mountComponent();

      formGroup = wrapper.findAllComponents(GlFormGroup).at(index);
      formInput = formGroup.findComponent(GlFormInput);
    });

    it('renders', () => {
      expect(formGroup.attributes()).toMatchObject({
        label,
        description,
      });

      expect(formInput.attributes('value')).toBe(value);
    });

    it('emits trimmed input event', () => {
      formInput.vm.$emit('input', trimmed ? '  new value  ' : 'new value');

      expect(wrapper.emitted('input')).toEqual([[{ ...defaultProps.value, [field]: 'new value' }]]);
    });
  });
});
