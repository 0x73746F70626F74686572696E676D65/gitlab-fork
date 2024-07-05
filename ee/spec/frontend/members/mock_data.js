import { member, dataAttribute as CEDataAttribute } from 'jest/members/mock_data';
import { MEMBERS_TAB_TYPES } from 'ee/members/constants';
import {
  data as promotionRequestsData,
  pagination as promotionRequestsPagination,
} from './promotion_requests/mock_data';

// eslint-disable-next-line import/export
export * from 'jest/members/mock_data';

export const bannedMember = {
  ...member,
  banned: true,
};

export const customRoles = [
  {
    baseAccessLevel: 20,
    name: 'custom role 3',
    memberRoleId: 103,
    description: 'custom role 3 description',
    permissions: [{ name: 'Permission 4', description: 'Permission description 4' }],
  },
  {
    baseAccessLevel: 10,
    name: 'custom role 1',
    description: 'custom role 1 description',
    memberRoleId: 101,
    permissions: [
      { name: 'Permission 0', description: 'Permission description 0' },
      { name: 'Permission 1', description: 'Permission description 1' },
    ],
  },
  {
    baseAccessLevel: 10,
    name: 'custom role 2',
    description: 'custom role 2 description',
    memberRoleId: 102,
    permissions: [
      { name: 'Permission 2', description: 'Permission description 2' },
      { name: 'Permission 3', description: 'Permission description 3' },
    ],
  },
];

export const upgradedMember = {
  ...member,
  accessLevel: {
    integerValue: 10,
    stringValue: 'custom role 1',
    memberRoleId: 101,
    description: 'custom role 1 description',
  },
  customRoles,
};

export const updateableCustomRoleMember = {
  ...upgradedMember,
  isDirectMember: true,
  canUpdate: true,
  memberPath: 'user/path/238',
  namespace: 'user',
};

// eslint-disable-next-line import/export
export const dataAttribute = JSON.stringify({
  ...JSON.parse(CEDataAttribute),
  [MEMBERS_TAB_TYPES.promotionRequest]: {
    data: promotionRequestsData,
    pagination: promotionRequestsPagination,
  },
});
