export const mockParentGroupItem = {
  id: 55,
  name: 'hardware',
  description: '',
  visibility: 'public',
  fullName: 'platform / hardware',
  relativePath: '/platform/hardware',
  canEdit: true,
  type: 'group',
  avatarUrl: null,
  permission: 'Owner',
  editPath: '/groups/platform/hardware/edit',
  childrenCount: 3,
  leavePath: '/groups/platform/hardware/group_members/leave',
  parentId: 54,
  memberCount: '1',
  projectCount: 1,
  subgroupCount: 2,
  canLeave: false,
  children: [],
  isOpen: true,
  isChildrenLoading: false,
  isBeingRemoved: false,
  updatedAt: '2017-04-09T18:40:39.101Z',
};

export const mockChildren = [
  {
    id: 57,
    name: 'bsp',
    description: '',
    visibility: 'public',
    fullName: 'platform / hardware / bsp',
    relativePath: '/platform/hardware/bsp',
    canEdit: true,
    type: 'group',
    avatarUrl: null,
    permission: 'Owner',
    editPath: '/groups/platform/hardware/bsp/edit',
    childrenCount: 6,
    leavePath: '/groups/platform/hardware/bsp/group_members/leave',
    parentId: 55,
    memberCount: '1',
    projectCount: 4,
    subgroupCount: 2,
    canLeave: false,
    children: [],
    isOpen: true,
    isChildrenLoading: false,
    isBeingRemoved: false,
    updatedAt: '2017-04-09T18:40:39.101Z',
    complianceFramework: {},
  },
  {
    id: 57,
    name: 'bsp',
    description: '',
    visibility: 'public',
    fullName: 'platform / hardware / bsp',
    relativePath: '/platform/hardware/bsp',
    canEdit: true,
    type: 'group',
    avatarUrl: null,
    permission: 'Owner',
    editPath: '/groups/platform/hardware/bsp/edit',
    childrenCount: 6,
    leavePath: '/groups/platform/hardware/bsp/group_members/leave',
    parentId: 55,
    memberCount: '1',
    projectCount: 4,
    subgroupCount: 2,
    canLeave: false,
    children: [],
    isOpen: true,
    isChildrenLoading: false,
    isBeingRemoved: false,
    updatedAt: '2017-04-09T18:40:39.101Z',
    complianceFramework: {
      id: 'gid://gitlab/ComplianceManagement::Framework/1',
      name: 'GDPR',
      description: 'General Data Protection Regulation',
      color: '#009966',
    },
  },
];

export const mockRawChildren = [
  {
    id: 57,
    name: 'bsp',
    description: '',
    visibility: 'public',
    full_name: 'platform / hardware / bsp',
    relative_path: '/platform/hardware/bsp',
    can_edit: true,
    type: 'group',
    avatar_url: null,
    permission: 'Owner',
    edit_path: '/groups/platform/hardware/bsp/edit',
    children_count: 6,
    leave_path: '/groups/platform/hardware/bsp/group_members/leave',
    parent_id: 55,
    number_users_with_delimiter: '1',
    project_count: 4,
    subgroup_count: 2,
    can_leave: false,
    children: [],
    updated_at: '2017-04-09T18:40:39.101Z',
  },
  {
    id: 57,
    name: 'bsp',
    description: '',
    visibility: 'public',
    full_name: 'platform / hardware / bsp',
    relative_path: '/platform/hardware/bsp',
    can_edit: true,
    type: 'group',
    avatar_url: null,
    permission: 'Owner',
    edit_path: '/groups/platform/hardware/bsp/edit',
    children_count: 6,
    leave_path: '/groups/platform/hardware/bsp/group_members/leave',
    parent_id: 55,
    number_users_with_delimiter: '1',
    project_count: 4,
    subgroup_count: 2,
    can_leave: false,
    children: [],
    updated_at: '2017-04-09T18:40:39.101Z',
    compliance_management_frameworks: [
      {
        id: 1,
        namespace_id: 1,
        name: 'GDPR',
        description: 'General Data Protection Regulation',
        color: '#009966',
        pipeline_configuration_full_path: null,
      },
    ],
  },
];
