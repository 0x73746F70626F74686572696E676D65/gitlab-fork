import { GlAlert, GlKeysetPagination } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import RolePromotionRequestsApp from 'ee/admin/role_promotion_requests/components/app.vue';
import PromotionRequestsTable from 'ee/admin/role_promotion_requests/components/promotion_requests_table.vue';
import usersQueuedForLicenseSeat from 'ee/admin/role_promotion_requests/graphql/users_queued_for_license_seat.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { defaultProvide, selfManagedUsersQueuedForRolePromotion } from '../mock_data';

Vue.use(VueApollo);

describe('RolePromotionRequestsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findPromotionRequestsTable = () => wrapper.findComponent(PromotionRequestsTable);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  const getUsersQueuedForLicenseSeatHandler = jest.fn();

  const createComponent = () => {
    wrapper = shallowMountExtended(RolePromotionRequestsApp, {
      apolloProvider: createMockApollo([
        [usersQueuedForLicenseSeat, getUsersQueuedForLicenseSeatHandler],
      ]),
      provide: defaultProvide,
    });
  };

  describe('Displaying pending promotion requests', () => {
    const result =
      selfManagedUsersQueuedForRolePromotion.data.selfManagedUsersQueuedForRolePromotion;

    beforeEach(async () => {
      getUsersQueuedForLicenseSeatHandler.mockResolvedValue(selfManagedUsersQueuedForRolePromotion);
      createComponent();
      await waitForPromises();
    });

    it('will display the PromotionRequestsTable', () => {
      const table = findPromotionRequestsTable();
      expect(table.props()).toEqual({
        list: result.nodes,
        isLoading: false,
      });
    });

    describe('pagination', () => {
      it('will display the pagination', () => {
        const pagination = findGlKeysetPagination();
        const { endCursor, hasNextPage, hasPreviousPage, startCursor } = result.pageInfo;

        expect(pagination.props()).toEqual(
          expect.objectContaining({ endCursor, hasNextPage, hasPreviousPage, startCursor }),
        );
      });

      it('will emit pagination', async () => {
        const pagination = findGlKeysetPagination();
        const after = result.pageInfo.endCursor;
        pagination.vm.$emit('next', after);
        await waitForPromises();
        expect(getUsersQueuedForLicenseSeatHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after,
            first: null,
            last: DEFAULT_PER_PAGE,
          }),
        );
      });
    });
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      getUsersQueuedForLicenseSeatHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('will set isLoading on PromotionRequestsTable props', () => {
      const table = findPromotionRequestsTable();
      expect(table.props()).toEqual(expect.objectContaining({ isLoading: true }));
    });

    it('will set disabled on the GlKeysetPagination props', () => {
      const pagination = findGlKeysetPagination();
      expect(pagination.props()).toEqual(expect.objectContaining({ disabled: true }));
    });
  });

  describe('Error state', () => {
    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException');
      getUsersQueuedForLicenseSeatHandler.mockRejectedValue({ error: Error('Error') });
      createComponent();
      await waitForPromises();
    });

    afterEach(() => {
      Sentry.captureException.mockRestore();
    });

    it('will display an error alert', () => {
      expect(findGlAlert().exists()).toBe(true);
    });

    it('will report the error to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
    });
  });
});
