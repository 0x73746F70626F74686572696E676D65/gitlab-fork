import { nextTick } from 'vue';
import { GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DEFAULT_PROJECT_TEMPLATES from 'ee/projects/default_project_templates';
import { DEFAULT_SELECTED_LABEL } from 'ee/registrations/groups/new/constants';
import ProjectTemplateSelector from 'ee/registrations/groups/new/components/project_template_selector.vue';

describe('ProjectTemplateSelector', () => {
  const templateName = 'plainhtml';

  const initialProps = {
    selectedTemplateName: '',
  };

  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ProjectTemplateSelector, {
      propsData: {
        ...initialProps,
        ...props,
      },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGlFormInput = () => wrapper.findComponent(GlFormInput);
  const findSelectedLogo = () => wrapper.findByTestId('selected-logo');

  describe('render', () => {
    it('renders dropdown', () => {
      createComponent();

      const dropdown = findGlCollapsibleListbox();

      expect(dropdown.props('items').map((item) => item.value)).toEqual([
        'express',
        'dotnetcore',
        'plainhtml',
        'laravel',
      ]);
    });

    it('preselects template name', () => {
      createComponent({ selectedTemplateName: templateName });

      expect(findGlCollapsibleListbox().props('selected')).toBe(templateName);
      expect(findGlFormInput().attributes('value')).toBe(templateName);
    });
  });

  describe('select', () => {
    it('selects tempate', async () => {
      createComponent();

      const listbox = findGlCollapsibleListbox();

      listbox.vm.$emit('select', templateName);

      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[templateName]]);
      expect(wrapper.text()).toEqual(DEFAULT_PROJECT_TEMPLATES[templateName].text);
      expect(listbox.props('selected')).toBe(templateName);
      expect(findSelectedLogo().exists()).toBe(true);
    });
  });

  describe('reset', () => {
    it('resets tempate', async () => {
      createComponent({ selectedTemplateName: templateName });

      const listbox = findGlCollapsibleListbox();

      listbox.vm.$emit('reset');

      await nextTick();

      expect(wrapper.emitted('select')).toEqual([[templateName], ['']]);
      expect(wrapper.text()).toEqual(DEFAULT_SELECTED_LABEL);
      expect(listbox.props('selected')).toBe('');
      expect(findSelectedLogo().exists()).toBe(false);
    });
  });
});
