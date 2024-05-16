import { member, dataAttribute as CEDataAttribute } from 'jest/members/mock_data';
import { MEMBER_TYPES } from 'ee/members/constants';
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
  { baseAccessLevel: 20, name: 'custom role 3', memberRoleId: 103 },
  {
    baseAccessLevel: 10,
    name: 'custom role 1',
    description: 'custom role 1 description',
    memberRoleId: 101,
  },
  { baseAccessLevel: 10, name: 'custom role 2', memberRoleId: 102 },
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

// eslint-disable-next-line import/export
export const dataAttribute = JSON.stringify({
  ...JSON.parse(CEDataAttribute),
  [MEMBER_TYPES.promotionRequest]: {
    data: promotionRequestsData,
    pagination: promotionRequestsPagination,
  },
});
