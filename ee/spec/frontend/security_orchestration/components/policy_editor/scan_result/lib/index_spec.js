import {
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_BOT_MESSAGE,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_BOT_MESSAGE,
  getPolicyYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  it.each`
    namespaceType              | includeBotComment | expected
    ${NAMESPACE_TYPES.GROUP}   | ${true}           | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_BOT_MESSAGE}
    ${NAMESPACE_TYPES.GROUP}   | ${false}          | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE}
    ${NAMESPACE_TYPES.PROJECT} | ${true}           | ${DEFAULT_SCAN_RESULT_POLICY_WITH_BOT_MESSAGE}
    ${NAMESPACE_TYPES.PROJECT} | ${false}          | ${DEFAULT_SCAN_RESULT_POLICY}
  `(
    'returns the yaml for the $namespaceType namespace and includeBotComment as $includeBotComment',
    ({ namespaceType, includeBotComment, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType), includeBotComment })).toEqual(
        expected,
      );
    },
  );
});
