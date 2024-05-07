import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Search Suggestion', () => {
  let wrapper;

  const createWrapper = ({ text, name, value, selected }) => {
    wrapper = shallowMountExtended(SearchSuggestion, {
      propsData: {
        text,
        name,
        value,
        selected,
      },
    });
  };

  const findGlSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);

  it.each`
    selected
    ${true}
    ${false}
  `('renders search suggestions as expected when selected is $selected', ({ selected }) => {
    createWrapper({
      text: 'My text',
      value: 'my_value',
      name: 'test',
      selected,
    });

    expect(wrapper.findComponent(SearchSuggestion).exists()).toBe(true);
    expect(wrapper.findByText('My text').exists()).toBe(true);
    expect(findGlSearchSuggestion().props('value')).toBe('my_value');
    expect(wrapper.findByTestId('test-icon-my_value').classes('gl-invisible')).toBe(!selected);
  });
});
