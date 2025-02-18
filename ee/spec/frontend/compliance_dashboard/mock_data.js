export const createUser = (id) => ({
  id: `gid://gitlab/User/${id}`,
  avatarUrl: `https://${id}`,
  name: `User ${id}`,
  username: `user-${id}`,
  webUrl: `http://localhost:3000/user-${id}`,
  __typename: 'UserCore',
});

export const createApprovers = (count) => {
  return Array(count)
    .fill(null)
    .map((_, id) => ({ ...createUser(id), id }));
};

export const createDefaultProjects = (count) => {
  return Array(count)
    .fill(null)
    .map((_, id) => ({
      id,
      name: `project-${id}`,
      fullPath: `group/project-${id}`,
    }));
};

export const createDefaultProjectsResponse = (projects) => ({
  data: {
    group: {
      id: '1',
      projects: {
        nodes: projects,
        __typename: 'Project',
      },
      __typename: 'Group',
    },
  },
});

const complianceFrameworksNodesMock = [
  {
    id: 'gid://gitlab/ComplianceManagement::Framework/1',
    name: 'Example Framework',
    description: 'asds',
    color: '#0000ff',
    __typename: 'ComplianceFramework',
    default: true,
  },
];

export const createComplianceAdherence = (id, checkName, complianceFrameworksNodes) => ({
  id: `gid://gitlab/Projects::ComplianceStandards::Adherence/${id}`,
  updatedAt: 'July 1, 2023',
  status: id % 2 === 0 ? 'SUCCESS' : 'FAIL',
  checkName,
  standard: 'GITLAB',
  project: {
    id: 'gid://gitlab/Project/1',
    name: 'Example Project',
    webUrl: 'example.com/groups/example-group/example-project',
    complianceFrameworks: {
      nodes: complianceFrameworksNodes,
    },
  },
});

export const createComplianceAdherencesResponse = ({
  count = 1,
  checkName = 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR',
  pageInfo = {},
  complianceFrameworksNodes = complianceFrameworksNodesMock,
} = {}) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      __typename: 'Group',
      projectComplianceStandardsAdherence: {
        __typename: 'ComplianceAdherenceConnection',
        nodes: Array(count)
          .fill(null)
          .map((_, id) => createComplianceAdherence(id, checkName, complianceFrameworksNodes)),
        pageInfo: {
          endCursor: 'abc',
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'abc',
          __typename: 'PageInfo',
          ...pageInfo,
        },
      },
    },
  },
});

export const createComplianceViolation = (id) => ({
  id: `gid://gitlab/MergeRequests::ComplianceViolation/${id}`,
  severityLevel: 'HIGH',
  reason: 'APPROVED_BY_COMMITTER',
  violatingUser: createUser(1),
  mergeRequest: {
    id: `gid://gitlab/MergeRequest/1`,
    title: `Merge request 1`,
    mergedAt: '2022-03-06T16:39:12Z',
    webUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/merge_requests/56',
    author: createUser(2),
    mergeUser: createUser(1),
    committers: {
      nodes: [createUser(1)],
      __typename: 'UserCoreConnection',
    },
    participants: {
      nodes: [createUser(1), createUser(2)],
      __typename: 'UserCoreConnection',
    },
    approvedBy: {
      nodes: [createUser(1)],
      __typename: 'UserCoreConnection',
    },
    ref: '!56',
    fullRef: 'gitlab-org/gitlab-shell!56',
    sourceBranch: 'master',
    sourceBranchExists: false,
    targetBranch: 'feature',
    targetBranchExists: false,
    project: {
      id: 'gid://gitlab/Project/2',
      avatarUrl: null,
      name: 'Gitlab Shell',
      webUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell',
      complianceFrameworks: {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Framework/1',
            name: 'GDPR',
            description: 'asds',
            color: '#0000ff',
            __typename: 'ComplianceFramework',
          },
        ],
        __typename: 'ComplianceFrameworkConnection',
      },
      __typename: 'Project',
    },
    __typename: 'MergeRequest',
  },
  __typename: 'ComplianceViolation',
});

export const createComplianceViolationsResponse = ({ count = 1, pageInfo = {} } = {}) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      __typename: 'Group',
      mergeRequestViolations: {
        __typename: 'ComplianceViolationConnection',
        nodes: Array(count)
          .fill(null)
          .map((_, id) => createComplianceViolation(id)),
        pageInfo: {
          endCursor: 'abc',
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'abc',
          __typename: 'PageInfo',
          ...pageInfo,
        },
      },
    },
  },
});

export const complianceFramework = {
  color: '#009966',
  description: 'General Data Protection Regulation',
  name: 'GDPR',
};

const createProject = ({ id, groupPath } = {}) => ({
  id: `gid://gitlab/Project/${id}`,
  name: `Project ${id}`,
  description: `Project description ${id}`,
  fullPath: `${groupPath}/project${id}`,
  webUrl: `${groupPath}/project${id}`,
  complianceFrameworks: {
    nodes: [
      {
        id: `gid://gitlab/ComplianceManagement::Framework/${id}`,
        name: 'some framework',
        default: false,
        description: 'this is a framework',
        color: '#3cb371',
        __typename: 'ComplianceFramework',
      },
    ],
    __typename: 'ComplianceFrameworkConnection',
  },
  __typename: 'Project',
});

export const createComplianceFrameworksResponse = ({
  count = 1,
  pageInfo = {},
  groupPath = 'foo',
} = {}) => {
  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        projects: {
          nodes: Array(count)
            .fill(null)
            .map((_, id) => createProject({ id, groupPath })),
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'eyJpZCI6IjQxIn0',
            endCursor: 'eyJpZCI6IjIyIn0',
            __typename: 'PageInfo',
            ...pageInfo,
          },
          __typename: 'ProjectConnection',
        },
        __typename: 'Group',
      },
    },
  };
};

export const createProjectSetComplianceFrameworkResponse = ({ errors } = {}) => ({
  data: {
    projectSetComplianceFramework: {
      __typename: 'ProjectSetComplianceFrameworkPayload',
      clientMutationId: '1',
      errors: errors ?? [],
      project: createProject({ id: 1 }),
    },
  },
});

const mockPageInfo = () => ({
  hasNextPage: true,
  hasPreviousPage: true,
  startCursor: 'start-cursor',
  endCursor: 'end-cursor',
  __typename: 'PageInfo',
});

export const createFramework = ({
  id,
  isDefault = false,
  projects = 0,
  groupPath = 'foo',
} = {}) => ({
  id: `gid://gitlab/ComplianceManagement::Framework/${id}`,
  name: `Some framework ${id}`,
  default: isDefault,
  description: `This is a framework ${id}`,
  color: `#3cb37${id}`,
  projects: {
    nodes: Array(projects)
      .fill(null)
      .map((_, pid) => createProject({ id: pid, groupPath })),
  },
  scanResultPolicies: {
    nodes: [
      {
        __typename: 'ScanResultPolicy',
        name: 'scan1',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            name: 'foo',
          },
        },
      },
      {
        __typename: 'ScanResultPolicy',
        name: 'scan2',
        source: {
          namespace: {
            id: `gid://gitlab/Group/${id}`,
            name: 'bar',
          },
        },
      },
    ],
    pageInfo: {
      startCursor: null,
    },
  },
  scanExecutionPolicies: {
    nodes: [],
    pageInfo: {
      startCursor: null,
    },
  },
  pipelineConfigurationFullPath: null,
  __typename: 'ComplianceFramework',
});

export const createComplianceFrameworksTokenResponse = () => {
  return {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Shell',
        __typename: 'Namespace',
        complianceFrameworks: {
          pageInfo: mockPageInfo(),
          nodes: [
            createFramework({
              id: 'gid://gitlab/ComplianceManagement::Framework/1',
              name: 'some framework',
            }),
            createFramework({
              id: 'gid://gitlab/ComplianceManagement::Framework/2',
              name: 'another framework',
            }),
          ],
          __typename: 'ComplianceFrameworkConnection',
        },
      },
    },
  };
};

export const createComplianceFrameworksReportResponse = ({
  count = 1,
  projects = 0,
  groupPath = 'group',
} = {}) => {
  return {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Org',
        complianceFrameworks: {
          pageInfo: mockPageInfo(),
          nodes: Array(count)
            .fill(null)
            .map((_, id) => createFramework({ id, projects, groupPath })),
          __typename: 'ComplianceFrameworkConnection',
        },
        __typename: 'Namespace',
      },
    },
  };
};

export const createComplianceFrameworksReportProjectsResponse = ({ count = 1 } = {}) => {
  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Gitlab Org',
        projects: {
          nodes: Array(count)
            .fill(null)
            .map((_, id) => createProject({ id })),
          __typename: 'ProjectConnection',
        },
        __typename: 'Group',
      },
    },
  };
};
