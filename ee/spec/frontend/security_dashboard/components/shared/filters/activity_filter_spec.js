import { GlCollapsibleListbox, GlBadge, GlIcon } from '@gitlab/ui';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import ActivityFilter, {
  ITEMS,
  GROUPS,
} from 'ee/security_dashboard/components/shared/filters/activity_filter.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';

const [, ...GROUPS_WITHOUT_DEFAULT] = GROUPS;

const DEFAULT_VALUE = 'STILL_DETECTED';

describe('Activity Filter component', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findItem = (value) => wrapper.findByTestId(`listbox-item-${value}`);
  const findHeader = (text) => wrapper.findByTestId(`header-${text}`);
  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const clickItem = (value) => findItem(value).trigger('click');

  const expectSelectedItems = (values) => {
    expect(findListbox().props('selected')).toEqual(values);
  };

  const unselectDefaultValue = () => clickItem(DEFAULT_VALUE);

  const createWrapper = ({ glFeatures = {} } = {}) => {
    wrapper = mountExtended(ActivityFilter, {
      stubs: { QuerystringSync: true, GlBadge: true },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        glFeatures: {
          ...glFeatures,
        },
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  it('renders the header text for each non default group', () => {
    GROUPS_WITHOUT_DEFAULT.forEach(({ text }) => {
      const header = findHeader(text);

      expect(header.text()).toContain(text);
    });
  });

  it('renders the badge for each group', () => {
    GROUPS_WITHOUT_DEFAULT.forEach(({ text, icon, variant }) => {
      const header = findHeader(text);

      expect(header.findComponent(GlBadge).attributes()).toMatchObject({
        icon,
        variant: variant ?? 'muted',
      });
    });
  });

  it('passes GROUPS with MR to listbox items', () => {
    expect(findListbox().props('items')).toEqual([...GROUPS]);
  });

  it('selects and unselects an item when clicked on', async () => {
    const { value } = ITEMS.HAS_ISSUE;
    await clickItem(value);

    expectSelectedItems([DEFAULT_VALUE, value]);

    await clickItem(value);

    expectSelectedItems([DEFAULT_VALUE]);
  });

  it.each(GROUPS_WITHOUT_DEFAULT.map((group) => [group.text, group]))(
    'allows only one item to be selected for the %s group',
    async (_groupName, group) => {
      await unselectDefaultValue();

      for await (const { value } of group.options) {
        await clickItem(value);

        expectSelectedItems([value]);
      }
    },
  );

  it('allows multiple selection of items across groups', async () => {
    await unselectDefaultValue();

    // Get the first item in each group and click on them.
    const values = GROUPS_WITHOUT_DEFAULT.map((group) => group.options[0].value);
    for await (const value of values) {
      await clickItem(value);
    }

    expectSelectedItems(values);
  });

  it('renders activity icon with tooltip', () => {
    const icon = findIcon();

    expect(icon.exists()).toBe(true);
    expect(getBinding(icon.element, 'gl-tooltip').value).toBe(
      'The Activity filter now defaults to showing only vulnerabilities that are "still detected". To see vulnerabilities regardless of their detection status, remove this filter.',
    );
  });

  describe('QuerystringSync component', () => {
    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'activity',
        value: [DEFAULT_VALUE],
      });
    });

    it.each`
      emitted                             | expected
      ${[ALL_ID]}                         | ${[ALL_ID]}
      ${[ITEMS.NO_LONGER_DETECTED.value]} | ${[ITEMS.NO_LONGER_DETECTED.value]}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      await findQuerystringSync().vm.$emit('input', emitted);

      expectSelectedItems(expected);
    });
  });

  describe('toggleText', () => {
    it(`is 'No longer detected' when only 'No longer detected' is selected`, async () => {
      await unselectDefaultValue();

      await clickItem(ITEMS.NO_LONGER_DETECTED.value);

      expect(findListbox().props('toggleText')).toBe('No longer detected');
    });

    it(`passes 'No longer detected +1 more' when 'No longer detected' and item from Issue group is selected`, async () => {
      await clickItem(ITEMS.NO_LONGER_DETECTED.value);
      await clickItem(ITEMS.HAS_ISSUE.value);

      expect(findListbox().props('toggleText')).toBe('No longer detected +1 more');
    });

    it(`passes 'Still detected' by default`, () => {
      expect(findListbox().props('toggleText')).toBe('Still detected');
    });

    it(`passes 'All activity' when no option is selected`, async () => {
      await unselectDefaultValue();

      expect(findListbox().props('toggleText')).toBe('All activity');
    });

    it(`passes 'All activity' when All option is selected`, async () => {
      await clickItem(ALL_ID);

      expect(findListbox().props('toggleText')).toBe('All activity');
    });
  });

  describe('filter-changed event', () => {
    it('is emitted with DEFAULT_VALUES when created', () => {
      expect(wrapper.emitted('filter-changed')[0][0]).toStrictEqual({
        hasIssues: undefined,
        hasResolution: false,
        hasMergeRequest: undefined,
        hasRemediations: undefined,
      });
    });

    it('emits the expected data for the all option', async () => {
      await clickItem(ALL_ID);

      expect(wrapper.emitted('filter-changed')[1][0]).toStrictEqual({
        hasIssues: undefined,
        hasResolution: undefined,
        hasMergeRequest: undefined,
        hasRemediations: undefined,
      });
    });

    const hasSelectedItems = [
      ITEMS.STILL_DETECTED.value,
      ITEMS.HAS_ISSUE.value,
      ITEMS.HAS_MERGE_REQUEST.value,
      ITEMS.HAS_SOLUTION.value,
    ];

    const hasNotSelectedItems = [
      ITEMS.NO_LONGER_DETECTED.value,
      ITEMS.DOES_NOT_HAVE_ISSUE.value,
      ITEMS.DOES_NOT_HAVE_MERGE_REQUEST.value,
      ITEMS.DOES_NOT_HAVE_SOLUTION.value,
    ];

    it.each`
      selectedItems          | hasIssues | hasResolution | hasMergeRequest | hasRemediations
      ${hasSelectedItems}    | ${true}   | ${false}      | ${true}         | ${true}
      ${hasNotSelectedItems} | ${false}  | ${true}       | ${false}        | ${false}
    `(
      'emits the expected data for $selectedItems',
      async ({ selectedItems, hasIssues, hasResolution, hasMergeRequest, hasRemediations }) => {
        await unselectDefaultValue();

        for await (const value of selectedItems) {
          await clickItem(value);
        }

        expectSelectedItems(selectedItems);
        expect(wrapper.emitted('filter-changed').at(-1)[0]).toEqual({
          hasIssues,
          hasMergeRequest,
          hasResolution,
          hasRemediations,
        });
      },
    );
  });
});
