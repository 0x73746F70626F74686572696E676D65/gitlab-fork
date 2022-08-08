import produce from 'immer';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { WIDGET_TYPE_LABELS } from '../constants';
import typeDefs from './typedefs.graphql';
import workItemQuery from './work_item.query.graphql';

export const temporaryConfig = {
  typeDefs,
  cacheConfig: {
    possibleTypes: {
      LocalWorkItemWidget: ['LocalWorkItemLabels'],
    },
    typePolicies: {
      WorkItem: {
        fields: {
          mockWidgets: {
            read(widgets) {
              return (
                widgets || [
                  {
                    __typename: 'LocalWorkItemLabels',
                    type: WIDGET_TYPE_LABELS,
                    allowScopedLabels: true,
                    nodes: [],
                  },
                ]
              );
            },
          },
          widgets: {
            merge(_, incoming) {
              return incoming;
            },
          },
        },
      },
    },
  },
};

export const resolvers = {
  Mutation: {
    localUpdateWorkItem(_, { input }, { cache }) {
      const sourceData = cache.readQuery({
        query: workItemQuery,
        variables: { id: input.id },
      });

      const data = produce(sourceData, (draftData) => {
        if (input.labels) {
          const labelsWidget = draftData.workItem.mockWidgets.find(
            (widget) => widget.type === WIDGET_TYPE_LABELS,
          );
          labelsWidget.nodes = [...input.labels];
        }
      });

      cache.writeQuery({
        query: workItemQuery,
        variables: { id: input.id },
        data,
      });
    },
  },
};

export function createApolloProvider() {
  Vue.use(VueApollo);

  const defaultClient = createDefaultClient(resolvers, temporaryConfig);

  return new VueApollo({
    defaultClient,
  });
}
