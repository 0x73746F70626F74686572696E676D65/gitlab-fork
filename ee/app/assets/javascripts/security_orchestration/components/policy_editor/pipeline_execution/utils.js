import { safeDump, safeLoad } from 'js-yaml';
import { hasInvalidKey } from '../utils';

/*
  Construct a policy object expected by the policy editor from a yaml manifest.
*/
export const fromYaml = ({ manifest, validateRuleMode = false }) => {
  try {
    const policy = safeLoad(manifest, { json: true });

    if (validateRuleMode) {
      /**
       * These values are what is supported by rule mode. If the yaml has any other values,
       * rule mode will be disabled. This validation should not be used to check whether
       * the yaml is a valid policy; that should be done on the backend with the official
       * schema. These values should not be retrieved from the backend schema because
       * the UI for new attributes may not be available.
       */
      const primaryKeys = [
        'type',
        'name',
        'description',
        'enabled',
        'pipeline_config_strategy',
        'policy_scope',
        'content',
      ];
      const contentKeys = ['include'];
      const pipelineConfigStrategies = ['inject_ci', 'override_project_ci'];

      const hasInvalidPipelineConfigStrategy = (strategy) =>
        !pipelineConfigStrategies.includes(strategy);

      return !(
        hasInvalidKey(policy, primaryKeys) ||
        hasInvalidKey(policy.content, contentKeys) ||
        hasInvalidPipelineConfigStrategy(policy.pipeline_config_strategy)
      )
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

/*
 Return yaml representation of a policy.
*/
export const policyToYaml = (policy) => {
  return safeDump(policy);
};

export const toYaml = (yaml) => {
  return safeDump(yaml);
};
