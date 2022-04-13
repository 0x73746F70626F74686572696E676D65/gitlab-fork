import {
  GlAlert,
  GlPagination,
  GlButton,
  GlTable,
  GlAvatarLink,
  GlAvatarLabeled,
  GlBadge,
  GlModal,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import StatisticsSeatsCard from 'ee/usage_quotas/components/statistics_seats_card.vue';
import SubscriptionSeats from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import { CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT } from 'ee/usage_quotas/seats/constants';
import { mockDataSeats, mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import FilterSortContainerRoot from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

Vue.use(Vuex);

const actionSpies = {
  fetchBillableMembersList: jest.fn(),
  fetchGitlabSubscription: jest.fn(),
  resetBillableMembers: jest.fn(),
  setBillableMemberToRemove: jest.fn(),
  setSearchQuery: jest.fn(),
};

const providedFields = {
  namespaceName: 'Test Group Name',
  namespaceId: '1000',
  seatUsageExportPath: '/groups/test_group/-/seat_usage.csv',
};

const fakeStore = ({ initialState, initialGetters }) =>
  new Vuex.Store({
    actions: actionSpies,
    getters: {
      tableItems: () => mockTableItems,
      ...initialGetters,
    },
    state: {
      isLoading: false,
      hasError: false,
      namespaceId: 1,
      members: [...mockDataSeats.data],
      total: 300,
      page: 1,
      perPage: 5,
      sort: 'last_activity_on_desc',
      ...providedFields,
      ...initialState,
    },
  });

describe('Subscription Seats', () => {
  let wrapper;

  const createComponent = ({
    initialState = {},
    mountFn = shallowMount,
    initialGetters = {},
  } = {}) => {
    return extendedWrapper(
      mountFn(SubscriptionSeats, {
        store: fakeStore({ initialState, initialGetters }),
      }),
    );
  };

  const findTable = () => wrapper.findComponent(GlTable);

  const findExportButton = () => wrapper.findByTestId('export-button');

  const findSearchBox = () => wrapper.findComponent(FilterSortContainerRoot);
  const findPagination = () => wrapper.findComponent(GlPagination);

  const findAllRemoveUserItems = () => wrapper.findAllByTestId('remove-user');
  const findErrorModal = () => wrapper.findComponent(GlModal);
  const findStatisticsCard = () => wrapper.findComponent(StatisticsCard);
  const findStatisticsSeatsCard = () => wrapper.findComponent(StatisticsSeatsCard);

  const serializeUser = (rowWrapper) => {
    const avatarLink = rowWrapper.findComponent(GlAvatarLink);
    const avatarLabeled = rowWrapper.findComponent(GlAvatarLabeled);

    return {
      avatarLink: {
        href: avatarLink.attributes('href'),
        alt: avatarLink.attributes('alt'),
      },
      avatarLabeled: {
        src: avatarLabeled.attributes('src'),
        size: avatarLabeled.attributes('size'),
        text: avatarLabeled.text(),
      },
    };
  };

  const serializeTableRow = (rowWrapper) => {
    const emailWrapper = rowWrapper.find('[data-testid="email"]');

    return {
      user: serializeUser(rowWrapper),
      email: emailWrapper.text(),
      tooltip: emailWrapper.find('span').attributes('title'),
      removeUserButtonExists: rowWrapper.findComponent(GlButton).exists(),
    };
  };

  const findSerializedTable = (tableWrapper) => {
    return tableWrapper.findAll('tbody tr').wrappers.map(serializeTableRow);
  };

  describe('actions', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    afterEach(() => {
      wrapper.destroy();
    });

    it('correct actions are called on create', () => {
      expect(actionSpies.fetchBillableMembersList).toHaveBeenCalled();
    });
  });

  describe('renders', () => {
    beforeEach(() => {
      wrapper = createComponent({
        mountFn: mount,
        initialGetters: {
          tableItems: () => mockTableItems,
        },
      });
    });

    afterEach(() => {
      wrapper.destroy();
    });

    describe('export button', () => {
      it('has the correct href', () => {
        expect(findExportButton().attributes().href).toBe(providedFields.seatUsageExportPath);
      });
    });

    describe('table content', () => {
      it('renders the correct data', () => {
        const serializedTable = findSerializedTable(findTable());

        expect(serializedTable).toMatchSnapshot();
      });
    });

    it('pagination is rendered and passed correct values', () => {
      const pagination = findPagination();

      expect(pagination.props()).toMatchObject({
        perPage: 5,
        totalItems: 300,
      });
    });

    describe('with error modal', () => {
      it('does not render the model if the user is not removable', async () => {
        await findAllRemoveUserItems().at(0).trigger('click');

        expect(findErrorModal().html()).toBe('');
      });

      it('renders the error modal if the user is removable', async () => {
        await findAllRemoveUserItems().at(2).trigger('click');

        expect(findErrorModal().text()).toContain(CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT);
      });
    });

    describe('members avatar', () => {
      it('shows the correct avatarLinks length', () => {
        const avatarLinks = findTable().findAllComponents(GlAvatarLink);
        expect(avatarLinks.length).toBe(4);
      });

      it.each(['group_invite', 'project_invite'])(
        'shows the correct badge for membership_type %s',
        (membershipType) => {
          const avatarLinks = findTable().findAllComponents(GlAvatarLink);
          const badgeText = (
            membershipType.charAt(0).toUpperCase() + membershipType.slice(1)
          ).replace('_', ' ');

          avatarLinks.wrappers.forEach((avatarLinkWrapper) => {
            const currentMember = mockTableItems.find(
              (item) => item.user.name === avatarLinkWrapper.attributes().alt,
            );

            if (membershipType === currentMember.user.membership_type) {
              expect(avatarLinkWrapper.findComponent(GlBadge).text()).toBe(badgeText);
            }
          });
        },
      );
    });

    describe('members details', () => {
      it.each`
        membershipType      | shouldShowDetails
        ${'project_invite'} | ${false}
        ${'group_invite'}   | ${false}
        ${'project_member'} | ${true}
        ${'group_member'}   | ${true}
      `(
        'when membershipType is $membershipType, shouldShowDetails should be $shouldShowDetails',
        ({ membershipType, shouldShowDetails }) => {
          const seatCells = findTable().findAll('[data-testid*="seat-cell-"]');

          seatCells.wrappers.forEach((seatCellWrapper) => {
            const currentMember = mockTableItems.find(
              (item) => seatCellWrapper.attributes('data-testid') === `seat-cell-${item.user.id}`,
            );

            if (membershipType === currentMember.user.membership_type) {
              expect(
                seatCellWrapper.find('[data-testid="toggle-seat-usage-details"]').exists(),
              ).toBe(shouldShowDetails);
            }
          });
        },
      );
    });
  });

  describe('statistics cards', () => {
    beforeEach(() => {
      wrapper = createComponent({
        initialState: {
          seatsInSubscription: 3,
          seatsInUse: 2,
          maxSeatsUsed: 3,
          seatsOwed: 1,
        },
      });
    });

    it('calls the correct action on create', () => {
      expect(actionSpies.fetchGitlabSubscription).toHaveBeenCalled();
    });

    it('renders <statistics-card> with the necessary props', () => {
      const statisticsCard = findStatisticsCard();

      expect(statisticsCard.exists()).toBe(true);
      expect(statisticsCard.props()).toEqual(
        expect.objectContaining({
          description: 'Seats in use / Seats in subscription',
          helpLink: '/help/subscription/gitlab_com/index#how-seat-usage-is-determined',
          percentage: 67,
          totalUnit: null,
          totalValue: '3',
          usageUnit: null,
          usageValue: '2',
        }),
      );
    });

    it('renders <statistics-seats-card> with the necessary props', () => {
      const statisticsSeatsCard = findStatisticsSeatsCard();

      expect(statisticsSeatsCard.exists()).toBe(true);
      expect(statisticsSeatsCard.props()).toEqual(
        expect.objectContaining({
          seatsOwed: 1,
          seatsUsed: 3,
        }),
      );
    });
  });

  describe('is loading', () => {
    beforeEach(() => {
      wrapper = createComponent({ initialState: { isLoading: true } });
    });

    afterEach(() => {
      wrapper.destroy();
    });

    it('displays table in loading state', () => {
      expect(findTable().attributes('busy')).toBe('true');
    });
  });

  describe('search box', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('input event triggers the setSearchQuery action', async () => {
      const SEARCH_STRING = 'search string';

      // fetchBillableMembersList is called once on created()
      expect(actionSpies.fetchBillableMembersList).toHaveBeenCalledTimes(1);

      await findSearchBox().vm.$emit('onFilter', [
        { type: 'filtered-search-term', value: { data: SEARCH_STRING } },
      ]);

      expect(actionSpies.setSearchQuery).toHaveBeenCalledWith(expect.any(Object), SEARCH_STRING);
    });
  });

  describe('pending members alert', () => {
    it.each`
      pendingMembersPagePath | pendingMembersCount | shouldBeRendered
      ${undefined}           | ${undefined}        | ${false}
      ${undefined}           | ${0}                | ${false}
      ${'fake-path'}         | ${0}                | ${false}
      ${'fake-path'}         | ${3}                | ${true}
    `(
      'rendering alert is $shouldBeRendered when pendingMembersPagePath=$pendingMembersPagePath and pendingMembersCount=$pendingMembersCount',
      ({ pendingMembersPagePath, pendingMembersCount, shouldBeRendered }) => {
        wrapper = createComponent({
          initialState: {
            pendingMembersCount,
            pendingMembersPagePath,
          },
        });

        expect(wrapper.findComponent(GlAlert).exists()).toBe(shouldBeRendered);
      },
    );
  });
});
