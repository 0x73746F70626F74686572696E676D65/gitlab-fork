import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';

/**
 * @param {Object} allowedValues
 * @param value
 * @param lowerCase
 * @returns {boolean}
 */
const validateFilter = (allowedValues, value, lowerCase = false) => {
  if (typeof value !== 'string') return false;

  return Object.values(allowedValues)
    .map((option) => (lowerCase ? option.value?.toLowerCase() : option.value))
    .includes(lowerCase ? value?.toLowerCase() : value);
};

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateTypeFilter = (value) =>
  validateFilter(POLICY_TYPE_FILTER_OPTIONS, value, true);

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateSourceFilter = (value) => validateFilter(POLICY_SOURCE_OPTIONS, value, true);

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param type
 * @returns {string|undefined|string}
 */
export const extractTypeParameter = (type) =>
  validateTypeFilter(type) ? type?.toUpperCase() : POLICY_TYPE_FILTER_OPTIONS.ALL.value;

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param source
 * @returns {string|undefined|string}
 */
export const extractSourceParameter = (source) =>
  validateSourceFilter(source) ? source?.toUpperCase() : POLICY_SOURCE_OPTIONS.ALL.value;
