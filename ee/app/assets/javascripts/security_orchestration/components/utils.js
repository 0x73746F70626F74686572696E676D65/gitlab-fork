import { isEmpty } from 'lodash';
import {
  EXCLUDING,
  INCLUDING,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

export const isPolicyInherited = (source) => source?.inherited === true;

export const policyHasNamespace = (source) => Boolean(source?.namespace);

/**
 * @param policyScope policy scope object on security policy
 * @returns {Boolean}
 */
export const isDefaultMode = (policyScope) => {
  const {
    complianceFrameworks: { nodes: frameworks } = {},
    excludingProjects: { nodes: excluding } = {},
    includingProjects: { nodes: including } = {},
  } = policyScope || {};

  const noScope = (items) => items?.length === 0;
  const existingDefaultScope = noScope(frameworks) && noScope(excluding) && noScope(including);

  return (
    policyScope === undefined ||
    policyScope === null ||
    isEmpty(policyScope) ||
    existingDefaultScope
  );
};

/**
 * Returns true if police scope has projects that are excluded from it
 * @param policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasExcludingProjects = (policyScope = {}) => {
  const { excludingProjects: { nodes: excluding = [] } = {} } = policyScope || {};
  return excluding?.filter(Boolean).length > 0;
};

/**
 * Returns true if policy scope applies to specific projects
 * @param policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasIncludingProjects = (policyScope = {}) => {
  const { includingProjects: { nodes: including = [] } = {} } = policyScope || {};
  return including?.filter(Boolean).length > 0;
};

/**
 * Based on existence excluding or including projects on policy scope
 * return appropriate key
 * @param policyScope policyScope policy scope object on security policy
 * @returns {string|INCLUDING|EXCLUDING}
 */
export const policyScopeProjectsKey = (policyScope = {}) => {
  return policyScopeHasIncludingProjects(policyScope) ? INCLUDING : EXCLUDING;
};

/**
 * Number of linked to policy scope projects
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Number}
 */
export const policyScopeProjectLength = (policyScope = {}) => {
  return (
    policyScope?.[`${policyScopeProjectsKey(policyScope)}Projects`]?.nodes?.filter(Boolean)
      .length || 0
  );
};

/**
 * Check if policy scope has compliance frameworks
 * @param policyScope policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasComplianceFrameworks = (policyScope = {}) => {
  const { complianceFrameworks: { nodes = [] } = {} } = policyScope || {};
  return nodes?.filter(Boolean).length > 0;
};

/**
 * Extract ids from compliance frameworks
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Array}
 */
export const policyScopeComplianceFrameworks = (policyScope = {}) => {
  return policyScope?.complianceFrameworks?.nodes || [];
};

/**
 * Extract ids from projects
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Object}
 */
export const policyScopeProjects = (policyScope = {}) => {
  const { nodes = [], pageInfo = {} } =
    policyScope?.[`${policyScopeProjectsKey(policyScope)}Projects`] || {};
  return {
    projects: nodes,
    pageInfo,
  };
};

/**
 * Check if namespace is a project type
 * @param namespaceType
 * @returns {boolean}
 */
export const isProject = (namespaceType) => namespaceType === NAMESPACE_TYPES.PROJECT;

/**
 * Check if namespace is a group type
 * @param namespaceType
 * @returns {boolean}
 */
export const isGroup = (namespaceType) => namespaceType === NAMESPACE_TYPES.GROUP;
