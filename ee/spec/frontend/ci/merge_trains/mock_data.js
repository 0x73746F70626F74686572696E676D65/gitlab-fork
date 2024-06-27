// Fixture located at ee/spec/frontend/fixtures/merge_trains.rb
import activeTrain from 'test_fixtures/ee/graphql/merge_trains/active_merge_trains.json';
import mergedTrain from 'test_fixtures/ee/graphql/merge_trains/completed_merge_trains.json';

// built with fixture data but manual pageInfo
// inserted for testing pagination and avoiding the need
// to create multiple cars on a train in fixtures
const trainWithPagination = {
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      mergeTrains: {
        nodes: [
          {
            targetBranch: 'master',
            cars: {
              ...activeTrain.data.project.mergeTrains.nodes[0].cars,
              pageInfo: {
                hasNextPage: true,
                hasPreviousPage: false,
                startCursor: 'eyJpZCI6IjQifQ',
                endCursor: 'eyJpZCI6IjQifQ',
              },
            },
          },
        ],
      },
    },
  },
};

export { activeTrain, mergedTrain, trainWithPagination };
