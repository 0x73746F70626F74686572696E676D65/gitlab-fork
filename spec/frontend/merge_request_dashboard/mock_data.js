export function createMockMergeRequest(mergeRequest = {}) {
  return {
    id: 1,
    reference: '!1',
    titleHtml: 'Title',
    webUrl: '/',
    author: {
      id: 1,
      avatarUrl: '/',
      name: 'name',
      username: 'username',
      webUrl: '/',
      webPath: '/',
    },
    milestone: null,
    labels: {
      nodes: [],
    },
    assignees: {
      nodes: [],
    },
    reviewers: {
      nodes: [],
    },
    headPipeline: null,
    userDiscussionsCount: 0,
    createdAt: '',
    updatedAt: '',
    __typename: 'MergeRequest',
    ...mergeRequest,
  };
}
