import { GlTableLite, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import { mockSelfHostedModelsList } from './mock_data';

describe('SelfHostedModelsTable', () => {
  let wrapper;

  const createComponent = ({ props }) => {
    const basePath = '/admin/ai/self_hosted_models';

    wrapper = mountExtended(SelfHostedModelsTable, {
      propsData: {
        basePath,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent({ props: { models: mockSelfHostedModelsList } });
  });

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findNthTableRow = (idx) => findTableRows().at(idx);
  const findDisclosureDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  it('renders the table component', () => {
    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    const expectedTableHeaderNames = [
      'Name',
      'Model',
      'Endpoint',
      'API key',
      '', // The 'edit' column does not have a header name
    ];

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  it('renders self-hosted model entries', () => {
    expect(findTableRows().length).toEqual(2);

    const firstModel = findNthTableRow(0);

    expect(firstModel.text()).toContain('mock-self-hosted-model-1');
    expect(firstModel.text()).toContain('mixtral');

    expect(firstModel.find('[data-testid="close-xs-icon"]').exists()).toBe(true);
  });

  it('renders a disclosure dropdown for each self-hosted model entry', () => {
    expect(findDisclosureDropdowns().length).toBe(2);
  });

  describe('Edit button', () => {
    it('routes to the correct path', () => {
      const firstModelEditButton = findDisclosureDropdownItems().at(0);
      const secondModelEditButton = findDisclosureDropdownItems().at(2);

      expect(firstModelEditButton.html()).toContain(`href="/admin/ai/self_hosted_models/1/edit"`);
      expect(secondModelEditButton.html()).toContain(`href="/admin/ai/self_hosted_models/2/edit"`);
    });
  });
});
