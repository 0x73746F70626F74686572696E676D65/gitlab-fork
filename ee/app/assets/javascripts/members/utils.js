import { uniqueId } from 'lodash';
import { __, s__ } from '~/locale';
import {
  generateBadges as CEGenerateBadges,
  roleDropdownItems as CERoleDropdownItems,
  isDirectMember,
} from '~/members/utils';

export {
  isGroup,
  isDirectMember,
  isCurrentUser,
  canRemove,
  canRemoveBlockedByLastOwner,
  canResend,
  canUpdate,
} from '~/members/utils';

export const generateBadges = ({ member, isCurrentUser, canManageMembers }) => [
  ...CEGenerateBadges({ member, isCurrentUser, canManageMembers }),
  {
    show: member.usingLicense,
    text: __('Is using seat'),
    variant: 'neutral',
  },
  {
    show: member.groupSso,
    text: __('SAML'),
    variant: 'info',
  },
  {
    show: member.groupManagedAccount,
    text: __('Managed Account'),
    variant: 'info',
  },
  {
    show: member.canOverride,
    text: __('LDAP'),
    variant: 'info',
  },
  {
    show: member.enterpriseUserOfThisGroup,
    text: __('Enterprise'),
    variant: 'info',
  },
];

/**
 * Creates the dropdowns options for static and custom roles
 *
 * @param {object} member
 *   @param {Map<string, number>} member.validRoles
 *   @param {Array<{baseAccessLevel: number, name: string, memberRoleId: number}>} member.customRoles
 */
export const roleDropdownItems = ({ validRoles, customRoles }) => {
  if (!customRoles?.length) {
    return CERoleDropdownItems({ validRoles });
  }

  const { flatten: staticRoleDropdownItems } = CERoleDropdownItems({ validRoles });

  const customRoleDropdownItems = customRoles.map(
    ({ baseAccessLevel, name, memberRoleId, description }) => ({
      accessLevel: baseAccessLevel,
      memberRoleId,
      text: name,
      value: uniqueId('role-custom-'),
      description,
    }),
  );

  return {
    flatten: [...staticRoleDropdownItems, ...customRoleDropdownItems],
    formatted: [
      {
        text: s__('MemberRole|Standard roles'),
        options: staticRoleDropdownItems,
      },
      {
        text: s__('MemberRole|Custom roles'),
        options: customRoleDropdownItems,
      },
    ],
  };
};

/**
 * Finds and returns unique value
 *
 * @param {Array<{accessLevel: number, memberRoleId: null|number, text: string, value: string}>} flattenDropdownItems
 * @param {object} member
 *   @param {{integerValue: number, memberRoleId: undefined|null|number}} member.accessLevel
 */
export const initialSelectedRole = (flattenDropdownItems, member) => {
  return flattenDropdownItems.find(
    ({ accessLevel, memberRoleId }) =>
      accessLevel === member.accessLevel.integerValue &&
      memberRoleId === (member.accessLevel.memberRoleId ?? null),
  )?.value;
};

export const canDisableTwoFactor = (member) => {
  return Boolean(member.canDisableTwoFactor);
};

export const canOverride = (member) => member.canOverride && isDirectMember(member);

export const canUnban = (member) => {
  return Boolean(member.banned) && member.canUnban;
};
