import { within } from '@testing-library/dom';
import { mount, createWrapper } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import {
  upgradedMember as memberMock,
  directMember,
  members,
  bannedMember,
} from 'ee_jest/members/mock_data';
import MembersTable from '~/members/components/table/members_table.vue';
import { MEMBERS_TAB_TYPES, TAB_QUERY_PARAM_VALUES } from '~/members/constants';

Vue.use(Vuex);

describe('MemberList', () => {
  let wrapper;

  const createStore = (state = {}) => {
    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: {
          namespaced: true,
          state: {
            members: [],
            tableFields: [],
            tableAttrs: {
              tr: { 'data-testid': 'member-row' },
            },
            pagination: {},
            ...state,
          },
        },
      },
    });
  };

  const createComponent = (state, props = {}) => {
    wrapper = mount(MembersTable, {
      store: createStore(state),
      propsData: {
        tabQueryParamValue: TAB_QUERY_PARAM_VALUES.group,
        ...props,
      },
      provide: {
        sourceId: 1,
        currentUserId: 1,
        namespace: MEMBERS_TAB_TYPES.user,
        canManageMembers: true,
      },
      stubs: [
        'user-limit-reached-alert',
        'member-avatar',
        'member-source',
        'expires-at',
        'created-at',
        'member-action-buttons',
        'max-role',
        'disable-two-factor-modal',
        'remove-group-link-modal',
        'remove-member-modal',
        'expiration-datepicker',
        'ldap-override-confirmation-modal',
      ],
    });
  };

  const getByTestId = (id, options) =>
    createWrapper(within(wrapper.element).getByTestId(id, options));
  const findTableCellByMemberId = (tableCellLabel, memberId) =>
    getByTestId(`members-table-row-${memberId}`).find(
      `[data-label="${tableCellLabel}"][role="cell"]`,
    );

  describe('fields', () => {
    describe('"Actions" field', () => {
      const memberCanOverride = {
        ...directMember,
        canOverride: true,
      };

      const memberCanUnban = {
        ...bannedMember,
        canUnban: true,
      };

      const memberCanDisableTwoFactor = {
        ...memberMock,
        canDisableTwoFactor: true,
      };

      const memberNoPermissions = {
        ...memberMock,
        id: 2,
      };

      describe.each([
        ['canOverride', memberCanOverride],
        ['canUnban', memberCanUnban],
        ['canDisableTwoFactor', memberCanDisableTwoFactor],
      ])('when one of the members has `%s` permissions', (_, memberWithPermission) => {
        it('renders the "Actions" field', () => {
          createComponent({
            members: [memberNoPermissions, memberWithPermission],
            tableFields: ['actions'],
          });

          expect(within(wrapper.element).queryByTestId('col-actions')).not.toBe(null);

          expect(
            findTableCellByMemberId('Actions', memberNoPermissions.id).classes(),
          ).toStrictEqual(['col-actions', '!gl-hidden', 'lg:!gl-table-cell', '!gl-align-middle']);
          expect(
            findTableCellByMemberId('Actions', memberWithPermission.id).classes(),
          ).toStrictEqual(['col-actions', '!gl-align-middle']);
        });
      });

      describe.each([['canOverride'], ['canUnban'], ['canDisableTwoFactor']])(
        'when none of the members has `%s` permissions',
        () => {
          it('does not render the "Actions" field', () => {
            createComponent({ members, tableFields: ['actions'] });

            expect(within(wrapper.element).queryByTestId('col-actions')).toBe(null);
          });
        },
      );
    });
  });

  describe('User limit reached alert', () => {
    describe('when on the access request tab', () => {
      it('shows the alert', () => {
        createComponent({}, { tabQueryParamValue: TAB_QUERY_PARAM_VALUES.accessRequest });

        expect(wrapper.html()).toContain(
          '<user-limit-reached-alert-stub></user-limit-reached-alert-stub>',
        );
      });
    });

    describe('when user is not on the acccess request tab', () => {
      it('does not show the alert', () => {
        createComponent();

        expect(wrapper.html()).not.toContain(
          '<user-limit-reached-alert-stub></user-limit-reached-alert-stub>',
        );
      });
    });
  });
});
