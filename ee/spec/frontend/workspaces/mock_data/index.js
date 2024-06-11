import { cloneDeep } from 'lodash';
import { TEST_HOST } from 'helpers/test_constants';
import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from 'ee/workspaces/common/constants';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  AGENT_MAPPING_STATUS_UNMAPPED,
} from 'ee/workspaces/agent_mapping/constants';

export const WORKSPACE = {
  __typename: 'Workspace',
  id: 1,
  name: 'Workspace 1',
  namespace: 'Namespace',
  projectId: 'gid://gitlab/Project/1',
  desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
  actualState: WORKSPACE_STATES.starting,
  url: `${TEST_HOST}/workspace/1`,
  devfileRef: 'main',
  devfilePath: '.devfile.yaml',
  devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
  createdAt: '2023-05-01T18:24:34Z',
};

export const PROJECT_ID = 1;
export const PROJECT_FULL_PATH = 'gitlab-org/subgroup/gitlab';

export const WORKSPACE_QUERY_RESULT = {
  data: {
    workspace: cloneDeep(WORKSPACE),
  },
};

export const USER_WORKSPACES_LIST_QUERY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      workspaces: {
        nodes: [
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
            name: 'workspace-1-1-idmi02',
            namespace: 'gl-rd-ns-1-1-idmi02',
            desiredState: 'Stopped',
            actualState: 'CreationRequested',
            url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-04-29T18:24:34Z',
          },
          {
            __typename: 'Workspace',
            id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
            name: 'workspace-1-1-rfu27q',
            namespace: 'gl-rd-ns-1-1-rfu27q',
            desiredState: 'Running',
            actualState: 'Running',
            url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
            devfileRef: 'main',
            devfilePath: '.devfile.yaml',
            devfileWebUrl: 'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
            projectId: 'gid://gitlab/Project/1',
            createdAt: '2023-05-01T18:24:34Z',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const USER_WORKSPACES_LIST_QUERY_EMPTY_RESULT = {
  data: {
    currentUser: {
      id: 1,
      workspaces: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

export const AGENT_WORKSPACES_LIST_QUERY_RESULT = {
  data: {
    project: {
      id: 1,
      clusterAgent: {
        id: 1,
        workspaces: {
          nodes: [
            {
              __typename: 'Workspace',
              id: 'gid://gitlab/RemoteDevelopment::Workspace/2',
              name: 'workspace-1-1-idmi02',
              namespace: 'gl-rd-ns-1-1-idmi02',
              desiredState: 'Stopped',
              actualState: 'CreationRequested',
              url: 'https://8000-workspace-1-1-idmi02.workspaces.localdev.me?tkn=password',
              devfileRef: 'main',
              devfilePath: '.devfile.yaml',
              devfileWebUrl:
                'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
              projectId: 'gid://gitlab/Project/1',
              createdAt: '2023-04-29T18:24:34Z',
            },
            {
              __typename: 'Workspace',
              id: 'gid://gitlab/RemoteDevelopment::Workspace/1',
              name: 'workspace-1-1-rfu27q',
              namespace: 'gl-rd-ns-1-1-rfu27q',
              desiredState: 'Running',
              actualState: 'Running',
              url: 'https://8000-workspace-1-1-rfu27q.workspaces.localdev.me?tkn=password',
              devfileRef: 'main',
              devfilePath: '.devfile.yaml',
              devfileWebUrl:
                'http://gdk.test:3000/gitlab-org/gitlab-shell/-/blob/main/.devfile.yaml',
              projectId: 'gid://gitlab/Project/1',
              createdAt: '2023-05-01T18:24:34Z',
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const AGENT_WORKSPACES_LIST_QUERY_EMPTY_RESULT = {
  data: {
    project: {
      id: 1,
      clusterAgent: {
        id: 1,
        workspaces: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const SEARCH_PROJECTS_QUERY_RESULT = {
  data: {
    projects: {
      nodes: [
        {
          id: 1,
          nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
          fullPath: 'gitlab-org/subgroup/gitlab',
          visibility: 'public',
        },
        {
          id: 2,
          nameWithNamespace: 'GitLab Org / Subgroup / GitLab Shell',
          fullPath: 'gitlab-org/subgroup/gitlab-shell',
          visibility: 'public',
        },
      ],
    },
  },
};

export const GET_PROJECT_DETAILS_QUERY_RESULT = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
      repository: {
        rootRef: 'main',
      },
      group: {
        id: 'gid://gitlab/Group/80',
        fullPath: 'gitlab-org/subgroup',
      },
    },
  },
};

export const GET_PROJECTS_DETAILS_QUERY_RESULT = {
  data: {
    projects: {
      nodes: [
        {
          id: 'gid://gitlab/Project/1',
          nameWithNamespace: 'Gitlab Org / Gitlab Shell',
          __typename: 'Project',
        },
      ],
      __typename: 'ProjectConnection',
    },
  },
};

export const GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT = {
  data: {
    group: {
      id: 'gid://gitlab/Group/80',
      fullPath: 'gitlab-org',
      clusterAgents: {
        nodes: [],
      },
    },
  },
};

export const GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT = {
  data: {
    group: {
      id: 'gid://gitlab/Group/80',
      fullPath: 'gitlab-org',
      clusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/1',
            name: 'rootgroup-agent',
            project: {
              id: 'gid://gitlab/Project/101',
              nameWithNamespace: 'GitLab Org / GitLab',
            },
          },
        ],
      },
    },
  },
};

export const GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_NO_AGENT = {
  data: {
    group: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      clusterAgents: {
        nodes: [],
      },
    },
  },
};

export const GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT = {
  data: {
    group: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      clusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'subgroup-agent',
            project: {
              id: 'gid://gitlab/Project/102',
              nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
            },
          },
        ],
      },
    },
  },
};

export const GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_DUPLICATES_ROOTGROUP = {
  data: {
    group: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      clusterAgents: {
        nodes: [
          GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT.data.group.clusterAgents
            .nodes[0],
          GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT.data.group.clusterAgents
            .nodes[0],
        ],
      },
    },
  },
};

export const GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      remoteDevelopmentClusterAgents: {
        nodes: [],
      },
    },
  },
};

export const GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/81',
      fullPath: 'gitlab-org/subgroup',
      remoteDevelopmentClusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/1',
            name: 'rootgroup-agent',
            project: {
              id: 'gid://gitlab/Project/101',
              nameWithNamespace: 'GitLab Org / GitLab Agent One',
            },
          },
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'rootgroup-agent-2',
            project: {
              id: 'gid://gitlab/Project/102',
              nameWithNamespace: 'GitLab Org / GitLab Agent Two',
            },
          },
        ],
      },
    },
  },
};

export const GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/81',
      mappedAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/1',
            name: 'rootgroup-agent',
            project: {
              id: 'gid://gitlab/Project/101',
              nameWithNamespace: 'GitLab Org / GitLab Agent One',
            },
          },
        ],
      },
      unmappedAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'rootgroup-agent-2',
            project: {
              id: 'gid://gitlab/Project/102',
              nameWithNamespace: 'GitLab Org / GitLab Agent Two',
            },
          },
        ],
      },
    },
  },
};

export const WORKSPACE_CREATE_MUTATION_RESULT = {
  data: {
    workspaceCreate: {
      errors: [],
      workspace: {
        ...cloneDeep(WORKSPACE),
        id: 2,
      },
    },
  },
};

export const WORKSPACE_UPDATE_MUTATION_RESULT = {
  data: {
    workspaceUpdate: {
      errors: [],
      workspace: {
        __typename: 'Workspace',
        id: WORKSPACE.id,
        actualState: WORKSPACE_STATES.running,
        desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
      },
    },
  },
};

export const CREATE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    namespaceCreateRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: [],
    },
  },
};

export const CREATE_CLUSTER_AGENT_MAPPING_MUTATION_WITH_ERROR_RESULT = {
  data: {
    namespaceCreateRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: ['Namespace cluster agent mapping already exists'],
    },
  },
};

export const DELETE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT = {
  data: {
    namespaceDeleteRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: [],
    },
  },
};

export const DELETE_CLUSTER_AGENT_MAPPING_MUTATION_WITH_ERROR_RESULT = {
  data: {
    namespaceDeleteRemoteDevelopmentClusterAgentMapping: {
      clientMutationId: null,
      errors: ['Namespace cluster agent mapping not found'],
    },
  },
};

export const MAPPED_CLUSTER_AGENT = {
  id: 'gid://gitlab/Clusters::Agent/1',
  name: 'rootgroup-agent',
  mappingStatus: AGENT_MAPPING_STATUS_MAPPED,
};

export const UNMAPPED_CLUSTER_AGENT = {
  id: 'gid://gitlab/Clusters::Agent/2',
  name: 'rootgroup-agent-2',
  mappingStatus: AGENT_MAPPING_STATUS_UNMAPPED,
};

export const NAMESPACE_ID = 'gid://gitlab/Group/81';
