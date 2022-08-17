import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlTable } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash from '~/flash';
import { resolvers } from '~/ci_variable_list/graphql/resolvers';
import { convertToGraphQLId } from '~/graphql_shared/utils';

import ciGroupVariables from '~/ci_variable_list/components/ci_group_variables.vue';
import ciVariableSettings from '~/ci_variable_list/components/ci_variable_settings.vue';
import ciVariableTable from '~/ci_variable_list/components/ci_variable_table.vue';
import getGroupVariables from '~/ci_variable_list/graphql/queries/group_variables.query.graphql';

import addGroupVariable from '~/ci_variable_list/graphql/mutations/group_add_variable.mutation.graphql';
import deleteGroupVariable from '~/ci_variable_list/graphql/mutations/group_delete_variable.mutation.graphql';
import updateGroupVariable from '~/ci_variable_list/graphql/mutations/group_update_variable.mutation.graphql';

import { genericMutationErrorText, variableFetchErrorText } from '~/ci_variable_list/constants';

import { mockGroupVariables, newVariable } from '../mocks';

jest.mock('~/flash');

Vue.use(VueApollo);

const mockProvide = {
  endpoint: '/variables',
  groupPath: '/namespace/group',
  groupId: 1,
};

describe('Ci Group Variable list', () => {
  let wrapper;

  let mockApollo;
  let mockVariables;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findCiTable = () => wrapper.findComponent(GlTable);
  const findCiSettings = () => wrapper.findComponent(ciVariableSettings);

  // eslint-disable-next-line consistent-return
  const createComponentWithApollo = async ({ isLoading = false } = {}) => {
    const handlers = [[getGroupVariables, mockVariables]];

    mockApollo = createMockApollo(handlers, resolvers);

    wrapper = shallowMount(ciGroupVariables, {
      provide: mockProvide,
      apolloProvider: mockApollo,
      stubs: { ciVariableSettings, ciVariableTable },
    });

    if (!isLoading) {
      return waitForPromises();
    }
  };

  beforeEach(() => {
    mockVariables = jest.fn();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('while queries are being fetch', () => {
    beforeEach(() => {
      createComponentWithApollo({ isLoading: true });
    });

    it('shows a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findCiTable().exists()).toBe(false);
    });
  });

  describe('when queries are resolved', () => {
    describe('successfuly', () => {
      beforeEach(async () => {
        mockVariables.mockResolvedValue(mockGroupVariables);

        await createComponentWithApollo();
      });

      it('passes down the expected environments as props', () => {
        expect(findCiSettings().props('environments')).toEqual([]);
      });

      it('passes down the expected variables as props', () => {
        expect(findCiSettings().props('variables')).toEqual(
          mockGroupVariables.data.group.ciVariables.nodes,
        );
      });

      it('createFlash was not called', () => {
        expect(createFlash).not.toHaveBeenCalled();
      });
    });

    describe('with an error for variables', () => {
      beforeEach(async () => {
        mockVariables.mockRejectedValue();

        await createComponentWithApollo();
      });

      it('calls createFlash with the expected error message', () => {
        expect(createFlash).toHaveBeenCalledWith({ message: variableFetchErrorText });
      });
    });
  });

  describe('mutations', () => {
    beforeEach(async () => {
      mockVariables.mockResolvedValue(mockGroupVariables);

      await createComponentWithApollo();
    });
    it.each`
      actionName  | mutation               | event
      ${'add'}    | ${addGroupVariable}    | ${'add-variable'}
      ${'update'} | ${updateGroupVariable} | ${'update-variable'}
      ${'delete'} | ${deleteGroupVariable} | ${'delete-variable'}
    `(
      'calls the right mutation when user performs $actionName variable',
      async ({ event, mutation }) => {
        jest.spyOn(wrapper.vm.$apollo, 'mutate').mockResolvedValue();
        await findCiSettings().vm.$emit(event, newVariable);

        expect(wrapper.vm.$apollo.mutate).toHaveBeenCalledWith({
          mutation,
          variables: {
            endpoint: mockProvide.endpoint,
            fullPath: mockProvide.groupPath,
            groupId: convertToGraphQLId('Group', mockProvide.groupId),
            variable: newVariable,
          },
        });
      },
    );

    it.each`
      actionName  | event                | mutationName
      ${'add'}    | ${'add-variable'}    | ${'addGroupVariable'}
      ${'update'} | ${'update-variable'} | ${'updateGroupVariable'}
      ${'delete'} | ${'delete-variable'} | ${'deleteGroupVariable'}
    `(
      'throws with the specific graphql error if present when user performs $actionName variable',
      async ({ event, mutationName }) => {
        const graphQLErrorMessage = 'There is a problem with this graphQL action';
        jest
          .spyOn(wrapper.vm.$apollo, 'mutate')
          .mockResolvedValue({ data: { [mutationName]: { errors: [graphQLErrorMessage] } } });
        await findCiSettings().vm.$emit(event, newVariable);
        await nextTick();

        expect(wrapper.vm.$apollo.mutate).toHaveBeenCalled();
        expect(createFlash).toHaveBeenCalledWith({ message: graphQLErrorMessage });
      },
    );

    it.each`
      actionName  | event
      ${'add'}    | ${'add-variable'}
      ${'update'} | ${'update-variable'}
      ${'delete'} | ${'delete-variable'}
    `(
      'throws generic error when the mutation fails with no graphql errors and user performs $actionName variable',
      async ({ event }) => {
        jest.spyOn(wrapper.vm.$apollo, 'mutate').mockImplementationOnce(() => {
          throw new Error();
        });
        await findCiSettings().vm.$emit(event, newVariable);

        expect(wrapper.vm.$apollo.mutate).toHaveBeenCalled();
        expect(createFlash).toHaveBeenCalledWith({ message: genericMutationErrorText });
      },
    );
  });
});
