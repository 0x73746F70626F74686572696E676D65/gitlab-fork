export const mockDefaultPermissions = [
  { name: 'Permission A', description: 'Description A', value: 'READ_CODE' },
  { name: 'Permission B', description: 'Description B', value: 'READ_VULNERABILITY' },
  { name: 'Permission C', description: 'Description C', value: 'ADMIN_VULNERABILITY' },
];

export const mockPermissions = {
  data: {
    memberRolePermissions: {
      nodes: mockDefaultPermissions,
    },
  },
};

export const mockMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      memberRoles: {
        nodes: [
          {
            baseAccessLevel: {
              integerValue: 20,
              stringValue: 'REPORTER',
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/1',
            name: 'Test',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
                {
                  name: 'Read vulnerability',
                  value: 'READ_VULNERABILITY',
                },
              ],
            },
            __typename: 'MemberRole',
          },
        ],
        __typename: 'MemberRoleConnection',
      },
      __typename: 'Group',
    },
  },
};
