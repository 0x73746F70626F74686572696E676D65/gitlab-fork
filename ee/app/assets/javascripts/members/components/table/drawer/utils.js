import { roleDropdownItems } from 'ee/members/utils';

export { callRoleUpdateApi, setMemberRole } from '~/members/components/table/drawer/utils';

export const getRoleDropdownItems = roleDropdownItems;

export const getMemberRole = (roles, member) => {
  const { stringValue, integerValue, memberRoleId = null } = member.accessLevel;
  const role = roles.find((r) => r.memberRoleId === memberRoleId && r.accessLevel === integerValue);
  // When the user is logged out or has the Minimal Access role, the member data won't have available custom roles,
  // only the current role data in the accessLevel property. This means that if the member has a custom role,
  // roles.find() won't return anything, so the role name won't show. To fix this, we'll manually create a role
  // object using the accessLevel data.
  return role || { text: stringValue, value: integerValue, memberRoleId };
};
