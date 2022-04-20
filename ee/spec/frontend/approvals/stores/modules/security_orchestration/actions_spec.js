import * as actions from 'ee/approvals/stores/modules/security_orchestration/actions';
import testAction from 'helpers/vuex_action_helper';
import * as types from 'ee/approvals/stores/modules/security_orchestration/mutation_types';
import getInitialState from 'ee/approvals/stores/modules/security_orchestration/state';
import { gqClient } from 'ee/threat_monitoring/utils';

describe('security orchestration actions', () => {
  describe('fetchScanResultPolicies', () => {
    it('sets SCAN_RESULT_POLICIES_FAILED when failing', () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(Promise.reject());

      return testAction(
        actions.fetchScanResultPolicies,
        'namespace/project',
        getInitialState(),
        [{ type: types.SCAN_RESULT_POLICIES_FAILED }],
        [],
      );
    });

    it('sets SCAN_RESULT_POLICIES_FAILED when succeeding', () => {
      const policies = [{ name: 'policyName', yaml: 'name: policyName' }];
      const expectedPolicies = [{ name: 'policyName', isSelected: false }];
      const queryResponse = { data: { project: { scanResultPolicies: { nodes: policies } } } };

      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);

      return testAction(
        actions.fetchScanResultPolicies,
        'namespace/project',
        getInitialState(),
        [{ type: types.SET_SCAN_RESULT_POLICIES, payload: expectedPolicies }],
        [],
      );
    });

    it('sets SCAN_RESULT_POLICIES_FAILED with empty payload if parsing failed', () => {
      const policies = [{ name: 'policyName', yaml: '' }];
      const expectedPolicies = [];
      const queryResponse = { data: { project: { scanResultPolicies: { nodes: policies } } } };

      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);

      return testAction(
        actions.fetchScanResultPolicies,
        'namespace/project',
        getInitialState(),
        [{ type: types.SET_SCAN_RESULT_POLICIES, payload: expectedPolicies }],
        [],
      );
    });
  });
});
