import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ToolToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tool_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { MOCK_SCANNERS } from './mock_data';

Vue.use(VueRouter);

describe('ToolToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['ALL'], operator: '||' },
    active = false,
    scanners = MOCK_SCANNERS,
    toolFilterType = 'scanner',
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ToolToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        toolFilterType,
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        scanners,
      },
      stubs: {
        QuerystringSync: true,
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findCheckedIcon = (value) => wrapper.findByTestId(`tool-icon-${value}`);
  const isOptionChecked = (v) => !findCheckedIcon(v).classes('gl-invisible');

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allOptionsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];

    if (wrapper.vm.toolFilterType === 'scanner') {
      return wrapper.vm.flatItems.map((i) => i.value).filter((i) => !exempt.includes(i));
    }

    return wrapper.vm.items.map((i) => i.value).filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    const findViewSlot = () => wrapper.findByTestId('slot-view');

    beforeEach(() => {
      createWrapper({
        stubs: {
          GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
            template: `
            <div>
                <div data-testid="slot-view">
                    <slot name="view"></slot>
                </div>
                <div data-testid="slot-suggestions">
                    <slot name="suggestions"></slot>
                </div>
            </div>`,
          }),
        },
      });
    });

    it('shows the label', () => {
      expect(findViewSlot().text()).toBe('All tools');
    });

    it('shows the dropdown with correct options', () => {
      // All options are rendered in the #suggestions slot of GlFilteredSearchToken
      const findDropdownOptions = () => wrapper.findByTestId('slot-suggestions');

      expect(
        findDropdownOptions()
          .text()
          .split('\n')
          .map((s) => s.trim())
          .filter((i) => i),
      ).toEqual([
        'Tool', // group header
        'All tools',
        'Manually added',
        'API Fuzzing', // group header
        'GitLab API Fuzzing',
        'Container Scanning', // group header
        'Trivy',
        'Coverage Fuzzing', // group header
        'libfuzzer',
        'DAST', // group header
        'OWASP Zed Attack Proxy (ZAP)',
        'Dependency Scanning', // group header
        'Gemnasium',
        'SAST', // group header
        'ESLint',
        'Find Security Bugs',
        'A Custom Scanner (SamScan)',
        'Secret Detection', // group header
        'GitLeaks',
      ]);
    });
  });

  describe('item selection - toolFilterType: scanner', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('gitlab-api-fuzzing', 'zaproxy');

      expect(isOptionChecked('gitlab-api-fuzzing')).toBe(true);
      expect(isOptionChecked('zaproxy')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All tool" when that item is selected', async () => {
      await clickDropdownItem('gitlab-api-fuzzing', 'zaproxy', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All tools" when last selected item is deselected', async () => {
      // Select and deselect "zaproxy"
      await clickDropdownItem('zaproxy', 'zaproxy');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('zaproxy', 'trivy', 'gemnasium', 'find_sec_bugs');
      expect(spy).toHaveBeenCalledWith({
        scanner: ['zaproxy', 'trivy', 'gemnasium', 'find_sec_bugs'],
      });
    });

    it('emits an empty filters-changed event when a all tools is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('ALL');
      expect(spy).toHaveBeenCalledWith({
        scanner: [],
      });
    });
  });

  describe('item selection - toolFilterType: reportType', () => {
    beforeEach(async () => {
      createWrapper({ toolFilterType: 'reportType' });
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('SAST', 'DAST');

      expect(isOptionChecked('SAST')).toBe(true);
      expect(isOptionChecked('DAST')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All tool" when that item is selected', async () => {
      await clickDropdownItem('SAST', 'DAST', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('SAST', 'DAST');
      expect(spy).toHaveBeenCalledWith({
        reportType: ['SAST', 'DAST'],
      });
    });

    it('emits an empty filters-changed event when a all tools is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('ALL');
      expect(spy).toHaveBeenCalledWith({
        reportType: [],
      });
    });
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, stubs: { QuerystringSync: false } });
      await nextTick();
    });

    it('emits filters-changed event and clears the query string', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('zaproxy', 'zaproxy');

      findFilteredSearchToken().vm.$emit('destroy');

      expect(spy).toHaveBeenCalledWith({
        scanner: [],
      });
    });
  });

  describe('toggle text', () => {
    const findViewSlot = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it.each(MOCK_SCANNERS.map((i) => [i.external_id, i.name, i.vendor]))(
      'when only "%s" is selected shows "%s" as placeholder text',
      async (externalId, scannerName, vendor) => {
        await clickDropdownItem(externalId);
        expect(findViewSlot().text()).toBe(
          `${scannerName}${vendor !== 'GitLab' ? ` (${vendor})` : ''}`,
        );
      },
    );

    it('shows "OWASP Zed Attack Proxy (ZAP) +1 more" when "zaproxy" and another option is selected', async () => {
      await clickDropdownItem('zaproxy', 'gitleaks');
      expect(findViewSlot().text()).toBe('OWASP Zed Attack Proxy (ZAP), GitLeaks');
    });

    it('shows "All tools" when "All tool" is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findViewSlot().text()).toBe('All tools');
    });
  });

  describe('QuerystringSync component - toolFilterType: scanners', () => {
    beforeEach(() => {
      createWrapper({});
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'scanner',
        value: ['ALL'],
        validValues: [
          'ALL',
          'gitlab-manual-vulnerability-report',
          'gitlab-api-fuzzing',
          'trivy',
          'libfuzzer',
          'zaproxy',
          'gemnasium',
          'eslint',
          'find_sec_bugs',
          'my_custom_scanner',
          'gitleaks',
        ],
      });
    });

    it('receives `ALL` when "All tools" option is clicked', async () => {
      await clickDropdownItem('ALL');

      expect(findQuerystringSync().props('value')).toEqual(['ALL']);
    });

    it.each`
      emitted                              | expected
      ${['zaproxy', 'gemnasium', 'trivy']} | ${['zaproxy', 'gemnasium', 'trivy']}
      ${['ALL']}                           | ${['ALL']}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      findQuerystringSync().vm.$emit('input', emitted);
      await nextTick();

      expected.forEach((item) => {
        expect(isOptionChecked(item)).toBe(true);
      });

      allOptionsExcept(expected).forEach((item) => {
        expect(isOptionChecked(item)).toBe(false);
      });
    });
  });

  describe('QuerystringSync component - toolFilterType: reportType', () => {
    beforeEach(() => {
      createWrapper({ toolFilterType: 'reportType' });
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'reportType',
        value: ['ALL'],
      });
    });

    it.each`
      emitted             | expected
      ${['SAST', 'DAST']} | ${['SAST', 'DAST']}
      ${['ALL']}          | ${['ALL']}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      findQuerystringSync().vm.$emit('input', emitted);
      await nextTick();

      expected.forEach((item) => {
        expect(isOptionChecked(item)).toBe(true);
      });

      allOptionsExcept(expected).forEach((item) => {
        expect(isOptionChecked(item)).toBe(false);
      });
    });
  });
});
