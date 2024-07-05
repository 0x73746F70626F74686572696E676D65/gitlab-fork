import { cloneDeep } from 'lodash';
import { getMemberRole, getRoleDropdownItems } from 'ee/members/components/table/drawer/utils';
import { roleDropdownItems } from 'ee/members/utils';
import { upgradedMember } from '../../../mock_data';

describe('Role details drawer utils', () => {
  describe('getRoleDropdownItems', () => {
    it('returns dropdown items', () => {
      expect(getRoleDropdownItems).toBe(roleDropdownItems);
    });
  });

  describe('getMemberRole', () => {
    const roles = getRoleDropdownItems(upgradedMember).flatten;

    it.each(roles)('returns $text role for member', (expectedRole) => {
      const member = cloneDeep(upgradedMember);
      member.accessLevel.integerValue = expectedRole.accessLevel;
      member.accessLevel.memberRoleId = expectedRole.memberRoleId;
      const role = getMemberRole(roles, member);

      expect(role).toBe(expectedRole);
    });
  });
});
