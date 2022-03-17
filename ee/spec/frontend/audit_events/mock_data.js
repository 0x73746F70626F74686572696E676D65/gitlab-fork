import { slugify } from '~/lib/utils/text_utility';

const DEFAULT_EVENT = {
  action: 'Signed in with STANDARD authentication',
  date: '2020-03-18 12:04:23',
  ip_address: '127.0.0.1',
};

const populateEvent = (user, hasAuthorUrl = true, hasObjectUrl = true) => {
  const author = { name: user, url: null };
  const object = { name: user, url: null };
  const userSlug = slugify(user);

  if (hasAuthorUrl) {
    author.url = `/${userSlug}`;
  }

  if (hasObjectUrl) {
    object.url = `http://127.0.0.1:3000/${userSlug}`;
  }

  return {
    ...DEFAULT_EVENT,
    author,
    object,
    target: user,
  };
};

export default () => [
  populateEvent('User'),
  populateEvent('User 2', false),
  populateEvent('User 3', true, false),
  populateEvent('User 4', false, false),
];

export const mockExternalDestinationUrl = 'https://api.gitlab.com';

export const mockExternalDestinations = [
  {
    destinationUrl: mockExternalDestinationUrl,
    id: 'test_id1',
  },
  {
    destinationUrl: 'https://apiv2.gitlab.com',
    id: 'test_id2',
  },
];

export const groupPath = 'test-group';

export const testGroupId = 'test-group-id';

export const destinationDataPopulator = (nodes) => ({
  data: {
    group: { id: testGroupId, externalAuditEventDestinations: { nodes } },
  },
});

export const destinationCreateMutationPopulator = (errors = []) => {
  const correctData = {
    errors,
    externalAuditEventDestination: {
      id: 'test-create-id',
      destinationUrl: mockExternalDestinationUrl,
      group: {
        name: groupPath,
        id: testGroupId,
      },
    },
  };

  const errorData = {
    errors,
    externalAuditEventDestination: {
      id: null,
      destinationUrl: null,
      group: {
        name: null,
        id: testGroupId,
      },
    },
  };

  return {
    data: {
      externalAuditEventDestinationCreate: errors.length > 0 ? errorData : correctData,
    },
  };
};

export const mockSvgPath = 'mock/path';
