export const mockDefaultPermissions = [
  { value: 'A', name: 'A', description: 'A', requirements: null, availableFromAccessLevel: null },
  { value: 'B', name: 'B', description: 'B', requirements: ['A'], availableFromAccessLevel: null },
  { value: 'C', name: 'C', description: 'C', requirements: ['B'], availableFromAccessLevel: null }, // Nested dependency: C -> B -> A
  { value: 'D', name: 'D', description: 'D', requirements: ['C'], availableFromAccessLevel: null }, // Nested dependency: D -> C -> B -> A
  { value: 'E', name: 'E', description: 'E', requirements: ['F'], availableFromAccessLevel: null }, // Circular dependency
  { value: 'F', name: 'F', description: 'F', requirements: ['E'], availableFromAccessLevel: null }, // Circular dependency
  {
    value: 'G',
    name: 'G',
    description: 'G',
    requirements: ['A', 'B', 'C'],
    availableFromAccessLevel: null,
  }, // Multiple dependencies
  {
    value: 'H',
    name: 'H',
    description: 'H',
    requirements: null,
    availableFromAccessLevel: { integerValue: 30 },
  }, // AvailableFromAccessLevel (no dependencies)
];

export const mockPermissions = {
  data: {
    memberRolePermissions: {
      nodes: mockDefaultPermissions,
    },
  },
};

export const mockEmptyMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      memberRoles: {
        nodes: [],
      },
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
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/1',
            name: 'Test',
            description: 'Test description',
            membersCount: 0,
            editPath: 'edit/path',
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
          {
            baseAccessLevel: {
              integerValue: 20,
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/2',
            name: 'Test 2',
            description: '',
            membersCount: 1,
            editPath: 'edit/path',
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

export const mockInstanceMemberRoles = {
  data: {
    memberRoles: {
      nodes: [
        {
          baseAccessLevel: {
            integerValue: 10,
            __typename: 'AccessLevel',
          },
          id: 'gid://gitlab/MemberRole/2',
          name: 'Instance Test',
          description: 'Instance Test description',
          membersCount: 0,
          editPath: 'edit/path',
          enabledPermissions: {
            nodes: [
              {
                name: 'Admin group',
                value: 'ADMIN_GROUP',
              },
            ],
          },
          __typename: 'MemberRole',
        },
      ],
      __typename: 'MemberRoleConnection',
    },
  },
};

export const mockMemberRoleQueryResponse = {
  data: {
    memberRole: {
      id: 1,
      name: 'Custom role',
      description: 'Custom role description',
      baseAccessLevel: { stringValue: 'DEVELOPER' },
      enabledPermissions: {
        nodes: [{ value: 'A' }, { value: 'B' }],
      },
    },
  },
};
