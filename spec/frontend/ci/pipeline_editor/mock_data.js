import { CI_CONFIG_STATUS_INVALID, CI_CONFIG_STATUS_VALID } from '~/ci/pipeline_editor/constants';
import { unwrapStagesWithNeeds } from '~/pipelines/components/unwrapping_utils';

export const mockProjectNamespace = 'user1';
export const mockProjectPath = 'project1';
export const mockProjectFullPath = `${mockProjectNamespace}/${mockProjectPath}`;
export const mockDefaultBranch = 'main';
export const mockNewBranch = 'new-branch';
export const mockNewMergeRequestPath = '/-/merge_requests/new';
export const mockCiLintPath = '/-/ci/lint';
export const mockCommitSha = 'aabbccdd';
export const mockCommitNextSha = 'eeffgghh';
export const mockIncludesHelpPagePath = '/-/includes/help';
export const mockLintHelpPagePath = '/-/lint-help';
export const mockCiTroubleshootingPath = '/-/pipeline-editor/troubleshoot';
export const mockSimulatePipelineHelpPagePath = '/-/simulate-pipeline-help';
export const mockYmlHelpPagePath = '/-/yml-help';
export const mockCommitMessage = 'My commit message';

export const mockCiConfigPath = '.gitlab-ci.yml';
export const mockCiYml = `
stages:
  - test
  - build

job_test_1:
  stage: test
  script:
    - echo "test 1"

job_test_2:
  stage: test
  script:
    - echo "test 2"

job_build:
  stage: build
  script:
    - echo "build"
  needs: ["job_test_2"]
`;

export const mockCiTemplateQueryResponse = {
  data: {
    project: {
      id: 'project-1',
      ciTemplate: {
        content: mockCiYml,
      },
    },
  },
};

export const mockBlobContentQueryResponse = {
  data: {
    project: {
      id: 'project-1',
      repository: { blobs: { nodes: [{ id: 'blob-1', rawBlob: mockCiYml }] } },
    },
  },
};

export const mockBlobContentQueryResponseNoCiFile = {
  data: {
    project: { id: 'project-1', repository: { blobs: { nodes: [] } } },
  },
};

export const mockBlobContentQueryResponseEmptyCiFile = {
  data: {
    project: { id: 'project-1', repository: { blobs: { nodes: [{ rawBlob: '' }] } } },
  },
};

const mockJobFields = {
  beforeScript: [],
  afterScript: [],
  environment: null,
  allowFailure: false,
  tags: [],
  when: 'on_success',
  only: { refs: ['branches', 'tags'], __typename: 'CiJobLimitType' },
  except: null,
  needs: { nodes: [], __typename: 'CiConfigNeedConnection' },
  __typename: 'CiConfigJob',
};

export const mockIncludesWithBlob = {
  location: 'test-include.yml',
  type: 'local',
  blob:
    'http://gdk.test:3000/root/upstream/-/blob/dd54f00bb3645f8ddce7665d2ffb3864540399cb/test-include.yml',
  raw:
    'http://gdk.test:3000/root/upstream/-/raw/dd54f00bb3645f8ddce7665d2ffb3864540399cb/test-include.yml',
  __typename: 'CiConfigInclude',
};

export const mockDefaultIncludes = {
  location: 'npm.gitlab-ci.yml',
  type: 'template',
  blob: null,
  raw:
    'https://gitlab.com/gitlab-org/gitlab/-/raw/master/lib/gitlab/ci/templates/npm.gitlab-ci.yml',
  __typename: 'CiConfigInclude',
};

export const mockIncludes = [
  mockDefaultIncludes,
  mockIncludesWithBlob,
  {
    location: 'a_really_really_long_name_for_includes_file.yml',
    type: 'local',
    blob:
      'http://gdk.test:3000/root/upstream/-/blob/dd54f00bb3645f8ddce7665d2ffb3864540399cb/a_really_really_long_name_for_includes_file.yml',
    raw:
      'http://gdk.test:3000/root/upstream/-/raw/dd54f00bb3645f8ddce7665d2ffb3864540399cb/a_really_really_long_name_for_includes_file.yml',
    __typename: 'CiConfigInclude',
  },
];

// Mock result of the graphql query at:
// app/assets/javascripts/ci/pipeline_editor/graphql/queries/ci_config.graphql
export const mockCiConfigQueryResponse = {
  data: {
    ciConfig: {
      errors: [],
      includes: mockIncludes,
      mergedYaml: mockCiYml,
      status: CI_CONFIG_STATUS_VALID,
      stages: {
        __typename: 'CiConfigStageConnection',
        nodes: [
          {
            name: 'test',
            groups: {
              nodes: [
                {
                  id: 'group-1',
                  name: 'job_test_1',
                  size: 1,
                  jobs: {
                    nodes: [
                      {
                        name: 'job_test_1',
                        script: ['echo "test 1"'],
                        ...mockJobFields,
                      },
                    ],
                    __typename: 'CiConfigJobConnection',
                  },
                  __typename: 'CiConfigGroup',
                },
                {
                  id: 'group-2',
                  name: 'job_test_2',
                  size: 1,
                  jobs: {
                    nodes: [
                      {
                        name: 'job_test_2',
                        script: ['echo "test 2"'],
                        ...mockJobFields,
                      },
                    ],
                    __typename: 'CiConfigJobConnection',
                  },
                  __typename: 'CiConfigGroup',
                },
              ],
              __typename: 'CiConfigGroupConnection',
            },
            __typename: 'CiConfigStage',
          },
          {
            name: 'build',
            groups: {
              nodes: [
                {
                  name: 'job_build',
                  size: 1,
                  jobs: {
                    nodes: [
                      {
                        name: 'job_build',
                        script: ['echo "build"'],
                        ...mockJobFields,
                      },
                    ],
                    __typename: 'CiConfigJobConnection',
                  },
                  __typename: 'CiConfigGroup',
                },
              ],
              __typename: 'CiConfigGroupConnection',
            },
            __typename: 'CiConfigStage',
          },
        ],
      },
      __typename: 'CiConfig',
    },
  },
};

export const mergeUnwrappedCiConfig = (mergedConfig) => {
  const { ciConfig } = mockCiConfigQueryResponse.data;
  return {
    ...ciConfig,
    stages: unwrapStagesWithNeeds(ciConfig.stages.nodes),
    ...mergedConfig,
  };
};

export const mockCommitShaResults = {
  data: {
    project: {
      id: '1',
      repository: {
        tree: {
          lastCommit: {
            id: 'commit-1',
            sha: mockCommitSha,
          },
        },
      },
    },
  },
};

export const mockNewCommitShaResults = {
  data: {
    project: {
      id: '1',
      repository: {
        tree: {
          lastCommit: {
            id: 'commit-1',
            sha: 'eeff1122',
          },
        },
      },
    },
  },
};

export const mockEmptyCommitShaResults = {
  data: {
    project: {
      id: '1',
      repository: {
        tree: {
          lastCommit: {
            id: 'commit-1',
            sha: '',
          },
        },
      },
    },
  },
};

export const mockProjectBranches = {
  data: {
    project: {
      id: '1',
      repository: {
        branchNames: [
          'main',
          'develop',
          'production',
          'test',
          'better-feature',
          'feature-abc',
          'update-ci',
          'mock-feature',
          'test-merge-request',
          'staging',
        ],
      },
    },
  },
};

export const mockTotalBranchResults =
  mockProjectBranches.data.project.repository.branchNames.length;

export const mockSearchBranches = {
  data: {
    project: {
      id: '1',
      repository: {
        branchNames: ['test', 'better-feature', 'update-ci', 'test-merge-request'],
      },
    },
  },
};

export const mockTotalSearchResults = mockSearchBranches.data.project.repository.branchNames.length;

export const mockEmptySearchBranches = {
  data: {
    project: {
      id: '1',
      repository: {
        branchNames: [],
      },
    },
  },
};

export const mockBranchPaginationLimit = 10;
export const mockTotalBranches = 20; // must be greater than mockBranchPaginationLimit to test pagination

export const mockProjectPipeline = ({ hasStages = true } = {}) => {
  const stages = hasStages
    ? {
        edges: [
          {
            node: {
              id: 'gid://gitlab/Ci::Stage/605',
              name: 'prepare',
              status: 'success',
              detailedStatus: {
                detailsPath: '/root/sample-ci-project/-/pipelines/268#prepare',
                group: 'success',
                hasDetails: true,
                icon: 'status_success',
                id: 'success-605-605',
                label: 'passed',
                text: 'passed',
                tooltip: 'passed',
              },
            },
          },
        ],
      }
    : null;

  return {
    id: '1',
    pipeline: {
      id: 'gid://gitlab/Ci::Pipeline/118',
      iid: '28',
      shortSha: mockCommitSha,
      status: 'SUCCESS',
      commit: {
        id: 'commit-1',
        title: 'Update .gitlabe-ci.yml',
        webPath: '/-/commit/aabbccdd',
      },
      detailedStatus: {
        id: 'status-1',
        detailsPath: '/root/sample-ci-project/-/pipelines/118',
        group: 'success',
        icon: 'status_success',
        text: 'passed',
      },
      stages,
    },
  };
};

export const mockLinkedPipelines = ({ hasDownstream = true, hasUpstream = true } = {}) => {
  let upstream = null;
  let downstream = {
    nodes: [],
    __typename: 'PipelineConnection',
  };

  if (hasDownstream) {
    downstream = {
      nodes: [
        {
          id: 'gid://gitlab/Ci::Pipeline/612',
          path: '/root/job-log-sections/-/pipelines/612',
          project: {
            id: 'gid://gitlab/Project/21',
            name: 'job-log-sections',
            __typename: 'Project',
          },
          detailedStatus: {
            id: 'success-612-612',
            group: 'success',
            icon: 'status_success',
            label: 'passed',
            __typename: 'DetailedStatus',
          },
          sourceJob: {
            id: 'gid://gitlab/Ci::Bridge/532',
            retried: false,
          },
          __typename: 'Pipeline',
        },
        {
          id: 'gid://gitlab/Ci::Pipeline/611',
          path: '/root/job-log-sections/-/pipelines/611',
          project: {
            id: 'gid://gitlab/Project/21',
            name: 'job-log-sections',
            __typename: 'Project',
          },
          detailedStatus: {
            id: 'success-611-611',
            group: 'success',
            icon: 'status_success',
            label: 'passed',
            __typename: 'DetailedStatus',
          },
          sourceJob: {
            id: 'gid://gitlab/Ci::Bridge/531',
            retried: true,
          },
          __typename: 'Pipeline',
        },
        {
          id: 'gid://gitlab/Ci::Pipeline/609',
          path: '/root/job-log-sections/-/pipelines/609',
          project: {
            id: 'gid://gitlab/Project/21',
            name: 'job-log-sections',
            __typename: 'Project',
          },
          detailedStatus: {
            id: 'success-609-609',
            group: 'success',
            icon: 'status_success',
            label: 'passed',
            __typename: 'DetailedStatus',
          },
          sourceJob: {
            id: 'gid://gitlab/Ci::Bridge/530',
            retried: true,
          },
          __typename: 'Pipeline',
        },
      ],
      __typename: 'PipelineConnection',
    };
  }

  if (hasUpstream) {
    upstream = {
      id: 'gid://gitlab/Ci::Pipeline/610',
      path: '/root/trigger-downstream/-/pipelines/610',
      project: {
        id: 'gid://gitlab/Project/21',
        name: 'trigger-downstream',
        __typename: 'Project',
      },
      detailedStatus: {
        id: 'success-610-610',
        group: 'success',
        icon: 'status_success',
        label: 'passed',
        __typename: 'DetailedStatus',
      },
      __typename: 'Pipeline',
    };
  }

  return {
    data: {
      project: {
        id: 'gid://gitlab/Project/21',
        pipeline: {
          id: 'gid://gitlab/Ci::Pipeline/790',
          path: '/root/ci-project/-/pipelines/790',
          downstream,
          upstream,
        },
        __typename: 'Project',
      },
    },
  };
};

export const mockLintResponse = {
  valid: true,
  mergedYaml: mockCiYml,
  status: CI_CONFIG_STATUS_VALID,
  errors: [],
  warnings: [],
  jobs: [
    {
      name: 'job_1',
      stage: 'test',
      before_script: ["echo 'before script 1'"],
      script: ["echo 'script 1'"],
      after_script: ["echo 'after script 1"],
      tag_list: ['tag 1'],
      environment: 'prd',
      when: 'on_success',
      allow_failure: false,
      only: null,
      except: { refs: ['main@gitlab-org/gitlab', '/^release/.*$/@gitlab-org/gitlab'] },
    },
    {
      name: 'job_2',
      stage: 'test',
      before_script: ["echo 'before script 2'"],
      script: ["echo 'script 2'"],
      after_script: ["echo 'after script 2"],
      tag_list: ['tag 2'],
      environment: 'stg',
      when: 'on_success',
      allow_failure: true,
      only: { refs: ['web', 'chat', 'pushes'] },
      except: { refs: ['main@gitlab-org/gitlab', '/^release/.*$/@gitlab-org/gitlab'] },
    },
  ],
};

export const mockLintResponseWithoutMerged = {
  valid: false,
  status: CI_CONFIG_STATUS_INVALID,
  errors: ['error'],
  warnings: [],
  jobs: [],
};

export const mockJobs = [
  {
    name: 'job_1',
    stage: 'build',
    beforeScript: [],
    script: ["echo 'Building'"],
    afterScript: [],
    tagList: [],
    environment: null,
    when: 'on_success',
    allowFailure: true,
    only: { refs: ['web', 'chat', 'pushes'] },
    except: null,
  },
  {
    name: 'multi_project_job',
    stage: 'test',
    beforeScript: [],
    script: [],
    afterScript: [],
    tagList: [],
    environment: null,
    when: 'on_success',
    allowFailure: false,
    only: { refs: ['branches', 'tags'] },
    except: null,
  },
  {
    name: 'job_2',
    stage: 'test',
    beforeScript: ["echo 'before script'"],
    script: ["echo 'script'"],
    afterScript: ["echo 'after script"],
    tagList: [],
    environment: null,
    when: 'on_success',
    allowFailure: false,
    only: { refs: ['branches@gitlab-org/gitlab'] },
    except: { refs: ['main@gitlab-org/gitlab', '/^release/.*$/@gitlab-org/gitlab'] },
  },
];

export const mockErrors = [
  '"job_1 job: chosen stage does not exist; available stages are .pre, build, test, deploy, .post"',
];

export const mockWarnings = [
  '"jobs:multi_project_job may allow multiple pipelines to run for a single action due to `rules:when` clause with no `workflow:rules` - read more: https://docs.gitlab.com/ee/ci/troubleshooting.html#pipeline-warnings"',
];

export const mockCommitCreateResponse = {
  data: {
    commitCreate: {
      __typename: 'CommitCreatePayload',
      errors: [],
      commit: {
        __typename: 'Commit',
        id: 'commit-1',
        sha: mockCommitNextSha,
      },
      commitPipelinePath: '',
    },
  },
};

export const mockAllRunnersQueryResponse = {
  data: {
    runners: {
      nodes: [
        {
          id: 'gid://gitlab/Ci::Runner/1',
          description: 'test',
          runnerType: 'PROJECT_TYPE',
          shortSha: 'DdTYMQGS',
          version: '15.6.1',
          ipAddress: '127.0.0.1',
          active: true,
          locked: true,
          jobCount: 0,
          jobExecutionStatus: 'IDLE',
          tagList: ['tag1', 'tag2', 'tag3'],
          createdAt: '2022-11-29T09:37:43Z',
          contactedAt: null,
          status: 'NEVER_CONTACTED',
          userPermissions: {
            updateRunner: true,
            deleteRunner: true,
            __typename: 'RunnerPermissions',
          },
          groups: null,
          ownerProject: {
            id: 'gid://gitlab/Project/1',
            name: '123',
            nameWithNamespace: 'Administrator / 123',
            webUrl: 'http://127.0.0.1:3000/root/test',
            __typename: 'Project',
          },
          __typename: 'CiRunner',
          upgradeStatus: 'NOT_AVAILABLE',
          adminUrl: 'http://127.0.0.1:3000/admin/runners/1',
          editAdminUrl: 'http://127.0.0.1:3000/admin/runners/1/edit',
        },
        {
          id: 'gid://gitlab/Ci::Runner/2',
          description: 'test',
          runnerType: 'PROJECT_TYPE',
          shortSha: 'DdTYMQGA',
          version: '15.6.1',
          ipAddress: '127.0.0.1',
          active: true,
          locked: true,
          jobCount: 0,
          jobExecutionStatus: 'IDLE',
          tagList: ['tag3', 'tag4'],
          createdAt: '2022-11-29T09:37:43Z',
          contactedAt: null,
          status: 'NEVER_CONTACTED',
          userPermissions: {
            updateRunner: true,
            deleteRunner: true,
            __typename: 'RunnerPermissions',
          },
          groups: null,
          ownerProject: {
            id: 'gid://gitlab/Project/1',
            name: '123',
            nameWithNamespace: 'Administrator / 123',
            webUrl: 'http://127.0.0.1:3000/root/test',
            __typename: 'Project',
          },
          __typename: 'CiRunner',
          upgradeStatus: 'NOT_AVAILABLE',
          adminUrl: 'http://127.0.0.1:3000/admin/runners/2',
          editAdminUrl: 'http://127.0.0.1:3000/admin/runners/2/edit',
        },
      ],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor:
          'eyJjcmVhdGVkX2F0IjoiMjAyMi0xMS0yOSAwOTozNzo0My40OTEwNTEwMDAgKzAwMDAiLCJpZCI6IjIifQ',
        endCursor:
          'eyJjcmVhdGVkX2F0IjoiMjAyMi0xMS0yOSAwOTozNzo0My40OTEwNTEwMDAgKzAwMDAiLCJpZCI6IjIifQ',
        __typename: 'PageInfo',
      },
      __typename: 'CiRunnerConnection',
    },
  },
};

export const mockCommitCreateResponseNewEtag = {
  data: {
    commitCreate: {
      __typename: 'CommitCreatePayload',
      errors: [],
      commit: {
        __typename: 'Commit',
        id: 'commit-2',
        sha: mockCommitNextSha,
      },
      commitPipelinePath: '/api/graphql:pipelines/sha/550ceace1acd373c84d02bd539cb9d4614f786db',
    },
  },
};
