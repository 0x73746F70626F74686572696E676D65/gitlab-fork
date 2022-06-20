export const mockEvents = [
  {
    action: 'comment',
    author: {
      __typename: 'UserCore',
      id: 'gid://gitlab/User/1',
      name: 'Administrator',
      username: 'root',
    },
    createdAt: '2022-03-22T15:59:08Z',
    id: 'gid://gitlab/IncidentManagement::TimelineEvent/132',
    note: 'Dummy event 1',
    noteHtml: '<p>Dummy event 1</p>',
    occurredAt: '2022-03-22T15:59:00Z',
    updatedAt: '2022-03-22T15:59:08Z',
    __typename: 'TimelineEventType',
  },
  {
    action: 'comment',
    author: {
      __typename: 'UserCore',
      id: 'gid://gitlab/User/1',
      name: 'Administrator',
      username: 'root',
    },
    createdAt: '2022-03-23T14:57:08Z',
    id: 'gid://gitlab/IncidentManagement::TimelineEvent/131',
    note: 'Dummy event 2',
    noteHtml: '<p>Dummy event 2</p>',
    occurredAt: '2022-03-23T14:57:00Z',
    updatedAt: '2022-03-23T14:57:08Z',
    __typename: 'TimelineEventType',
  },
  {
    action: 'comment',
    author: {
      __typename: 'UserCore',
      id: 'gid://gitlab/User/1',
      name: 'Administrator',
      username: 'root',
    },
    createdAt: '2022-03-23T15:59:08Z',
    id: 'gid://gitlab/IncidentManagement::TimelineEvent/132',
    note: 'Dummy event 3',
    noteHtml: '<p>Dummy event 3</p>',
    occurredAt: '2022-03-23T15:59:00Z',
    updatedAt: '2022-03-23T15:59:08Z',
    __typename: 'TimelineEventType',
  },
];

export const timelineEventsQueryListResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/8',
      incidentManagementTimelineEvents: {
        nodes: mockEvents,
      },
    },
  },
};

export const timelineEventsQueryEmptyResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/8',
      incidentManagementTimelineEvents: {
        nodes: [],
      },
    },
  },
};
