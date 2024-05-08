import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';

const mockApolloHandlers = () => {
  return {
    getGroupProjects: jest.fn().mockResolvedValue({
      data: {
        id: 1,
        group: {
          id: 2,
          projects: {
            nodes: [],
          },
        },
      },
    }),
  };
};

export const createMockApolloProvider = () => {
  Vue.use(VueApollo);
  return createMockApollo([[getGroupProjects, mockApolloHandlers]]);
};
