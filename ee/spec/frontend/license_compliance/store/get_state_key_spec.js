import getStateKey from 'ee/vue_merge_request_widget/stores/get_state_key';
import { DETAILED_MERGE_STATUS, MWCP_MERGE_STRATEGY } from '~/vue_merge_request_widget/constants';

describe('getStateKey', () => {
  const canMergeContext = {
    canMerge: true,
    commitsCount: 2,
  };

  describe('AutoMergeStrategy "merge_when_checks_pass"', () => {
    const createContext = (detailedMergeStatus, preferredAutoMergeStrategy, autoMergeEnabled) => ({
      ...canMergeContext,
      detailedMergeStatus,
      preferredAutoMergeStrategy,
      autoMergeEnabled,
    });

    it.each`
      scenario                   | detailedMergeStatus                   | preferredAutoMergeStrategy | autoMergeEnabled | state
      ${'MWCP and not approved'} | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${MWCP_MERGE_STRATEGY}     | ${false}         | ${'readyToMerge'}
      ${'MWCP and approved'}     | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${MWCP_MERGE_STRATEGY}     | ${false}         | ${'readyToMerge'}
    `(
      'when $scenario, state should equal $state',
      ({ detailedMergeStatus, preferredAutoMergeStrategy, autoMergeEnabled, state }) => {
        const bound = getStateKey.bind(
          createContext(detailedMergeStatus, preferredAutoMergeStrategy, autoMergeEnabled),
        );

        expect(bound()).toBe(state);
      },
    );
  });
});
