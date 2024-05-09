import { safeLoad } from 'js-yaml';
import { isBoolean, isEqual, uniqBy } from 'lodash';
import { addIdsToPolicy, hasInvalidKey, isValidPolicy } from '../../utils';
import { PRIMARY_POLICY_KEYS } from '../../constants';
import {
  VALID_APPROVAL_SETTINGS,
  PERMITTED_INVALID_SETTINGS,
  PERMITTED_INVALID_SETTINGS_KEY,
} from './settings';

/*
  Construct a policy object expected by the policy editor from a yaml manifest.
*/
export const fromYaml = ({ manifest, validateRuleMode = false }) => {
  try {
    const policy = addIdsToPolicy(safeLoad(manifest, { json: true }));

    if (validateRuleMode) {
      /**
       * These values are what is supported by rule mode. If the yaml has any other values,
       * rule mode will be disabled. This validation should not be used to check whether
       * the yaml is a valid policy; that should be done on the backend with the official
       * schema. These values should not be retrieved from the backend schema because
       * the UI for new attributes may not be available.
       */

      const primaryKeys = [...PRIMARY_POLICY_KEYS, 'fallback_behavior'];

      const rulesKeys = [
        'type',
        'branches',
        'branch_type',
        'branch_exceptions',
        'commits',
        'license_states',
        'license_types',
        'scanners',
        'severity_levels',
        'vulnerabilities_allowed',
        'vulnerability_states',
        'vulnerability_age',
        'vulnerability_attributes',
        'id',
        'match_on_inclusion_license',
      ];
      const actionsKeys = [
        'type',
        'approvals_required',
        'user_approvers',
        'group_approvers',
        'user_approvers_ids',
        'group_approvers_ids',
        'role_approvers',
        'id',
        'enabled',
      ];

      const { actions, approval_settings: settings = {} } = policy;

      // Temporary workaround to allow the rule builder to load with wrongly persisted settings
      const hasInvalidApprovalSettings = hasInvalidKey(settings, [
        ...VALID_APPROVAL_SETTINGS,
        PERMITTED_INVALID_SETTINGS_KEY,
      ]);

      const hasInvalidSettingStructure = !isEqual(settings, PERMITTED_INVALID_SETTINGS)
        ? !Object.values(settings).every((setting) => isBoolean(setting))
        : false;

      const hasInvalidActions =
        actions?.length > 2 ||
        (actions?.length && actions.length !== uniqBy(actions, 'type').length);

      return isValidPolicy({ policy, primaryKeys, rulesKeys, actionsKeys }) &&
        !hasInvalidApprovalSettings &&
        !hasInvalidSettingStructure &&
        !hasInvalidActions
        ? policy
        : { error: true };
    }

    return policy;
  } catch {
    /**
     * Catch parsing error of safeLoad
     */
    return { error: true, key: 'yaml-parsing' };
  }
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest) => {
  const policy = fromYaml({ manifest, validateRuleMode: true });

  return { policy, hasParsingError: Boolean(policy.error) };
};
