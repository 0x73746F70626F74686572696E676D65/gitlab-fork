import getStateQueryResponse from 'test_fixtures/graphql/merge_requests/get_state.query.graphql.json';
import MergeRequestStore from 'ee/vue_merge_request_widget/stores/mr_widget_store';
import mockData from 'ee_jest/vue_merge_request_widget/mock_data';

import { convertToCamelCase } from '~/lib/utils/text_utility';
import { stateKey } from '~/vue_merge_request_widget/stores/state_maps';
import {
  MWPS_MERGE_STRATEGY,
  MWCP_MERGE_STRATEGY,
  DETAILED_MERGE_STATUS,
} from '~/vue_merge_request_widget/constants';

describe('MergeRequestStore', () => {
  let store;

  beforeEach(() => {
    store = new MergeRequestStore(mockData);
  });

  describe('isNothingToMergeState', () => {
    it('returns true when nothingToMerge', () => {
      store.state = stateKey.nothingToMerge;

      expect(store.isNothingToMergeState).toEqual(true);
    });

    it('returns false when not nothingToMerge', () => {
      store.state = 'state';

      expect(store.isNothingToMergeState).toEqual(false);
    });
  });

  describe('setData', () => {
    describe('mergePipelinesEnabled', () => {
      it('should set mergePipelinesEnabled = true when merge_pipelines_enabled is true', () => {
        store.setData({ ...mockData, merge_pipelines_enabled: true });

        expect(store.mergePipelinesEnabled).toBe(true);
      });

      it('should set mergePipelinesEnabled = false when merge_pipelines_enabled is not provided', () => {
        store.setData({ ...mockData, merge_pipelines_enabled: undefined });

        expect(store.mergePipelinesEnabled).toBe(false);
      });
    });
  });

  describe('setGraphqlData', () => {
    const { mergeRequest } = getStateQueryResponse.data.project;

    it('sets mergeTrainsCount and mergeTrainIndex', () => {
      store.setGraphqlData({
        mergeRequest: {
          ...mergeRequest,
          mergeTrainsCount: 2,
          mergeTrainIndex: 1,
        },
      });

      expect(store.mergeTrainsCount).toBe(2);
      expect(store.mergeTrainIndex).toBe(1);
    });
  });

  describe('setGraphqlSubscriptionData', () => {
    it('sets mergeTrainsCount and mergeTrainIndex', () => {
      store.setGraphqlSubscriptionData({
        mergeTrainsCount: 2,
        mergeTrainIndex: 1,
      });

      expect(store.mergeTrainsCount).toBe(2);
      expect(store.mergeTrainIndex).toBe(1);
    });
  });

  describe('setPaths', () => {
    it.each([
      'discover_project_security_path',
      'container_scanning_comparison_path',
      'dependency_scanning_comparison_path',
      'sast_comparison_path',
      'dast_comparison_path',
      'secret_detection_comparison_path',
      'api_fuzzing_comparison_path',
      'coverage_fuzzing_comparison_path',
      'saml_approval_path',
    ])('should set %s path', (property) => {
      // Ensure something is set in the mock data
      expect(property in mockData).toBe(true);
      const expectedValue = mockData[property];

      store.setPaths({ ...mockData });

      expect(store[convertToCamelCase(property)]).toBe(expectedValue);
    });
  });

  describe('preventMerge', () => {
    beforeEach(() => {
      store.hasApprovalsAvailable = true;
    });

    it('is false when MR is approved', () => {
      store.setApprovals({ approved: true });

      expect(store.preventMerge).toBe(false);
    });

    it('is true when MR is not approved', () => {
      store.setApprovals({ approved: false });

      expect(store.preventMerge).toBe(true);
    });

    it('is true when MR is not approved and preferredAutoMergeStrategy is MWPS', () => {
      store.setData({
        ...mockData,
        available_auto_merge_strategies: [MWPS_MERGE_STRATEGY],
      });

      store.setApprovals({ approved: false });

      expect(store.preventMerge).toBe(true);
    });

    it('is false when MR is not approved and preferredAutoMergeStrategy is MWCP', () => {
      store.setData({ ...mockData, available_auto_merge_strategies: [MWCP_MERGE_STRATEGY] });

      store.setApprovals({ approved: false });

      expect(store.preventMerge).toBe(false);
    });
  });

  describe('hasMergeChecksFailed', () => {
    it('should be true when detailed merge status is EXTERNAL_STATUS_CHECKS', () => {
      store.detailedMergeStatus = DETAILED_MERGE_STATUS.EXTERNAL_STATUS_CHECKS;

      expect(store.hasMergeChecksFailed).toBe(true);
    });

    it('should be false when preferredAutoMergeStrategy is MWCP and MR is not approved', () => {
      store.hasApprovalsAvailable = true;
      store.detailedMergeStatus = DETAILED_MERGE_STATUS.NOT_APPROVED;

      store.setData({ ...mockData, available_auto_merge_strategies: [MWCP_MERGE_STRATEGY] });

      store.setApprovals({ isApproved: false, approvalsLeft: 1 });

      expect(store.hasMergeChecksFailed).toBe(false);
    });
  });
});
