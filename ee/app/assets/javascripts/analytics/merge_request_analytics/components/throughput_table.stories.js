import createMockApollo from 'helpers/mock_apollo_helper';
import { withVuexStore } from 'storybook_addons/vuex_store';
import ThroughputTable from 'ee/analytics/merge_request_analytics/components/throughput_table.vue';
import filters from '~/vue_shared/components/filtered_search_bar/store/modules/filters';
import throughputTableQuery from '../graphql/queries/throughput_table.query.graphql';
import {
  throughputTableData,
  throughputTableNoData,
  startDate,
  endDate,
  fullPath,
} from './stories_constants';

const defaultQueryResolver = { data: throughputTableData };

export default {
  component: ThroughputTable,
  title: 'ee/analytics/merge_request_analytics/components/throughput_table',
  decorators: [withVuexStore],
};

const createStory = ({ mockApollo, requestHandler = defaultQueryResolver } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [throughputTableQuery, () => Promise.resolve(requestHandler)],
  ]);

  return (args, { argTypes, createVuexStore }) => ({
    components: { ThroughputTable },
    apolloProvider: mockApollo || defaultApolloProvider,
    store: createVuexStore({
      modules: { filters },
    }),
    provide: {
      fullPath,
    },
    props: Object.keys(argTypes),
    template: '<throughput-table v-bind="$props"/>',
  });
};

export const Default = {
  render: createStory(),
  args: {
    startDate,
    endDate,
  },
};

export const NoData = {
  render: createStory({ requestHandler: { data: throughputTableNoData } }),
  args: Default.args,
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[throughputTableQuery, () => new Promise(() => {})]]),
  }),
  args: Default.args,
};
