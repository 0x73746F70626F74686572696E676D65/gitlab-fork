import { mount } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlLink, GlTableLite } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import WorkspacesTable from 'ee/workspaces/common/components/workspaces_list/workspaces_table.vue';
import WorkspaceActions from 'ee/workspaces/common/components/workspace_actions.vue';
import WorkspaceStateIndicator from 'ee/workspaces/common/components/workspace_state_indicator.vue';
import { populateWorkspacesWithProjectDetails } from 'ee/workspaces/common/services/utils';
import { WORKSPACE_STATES, WORKSPACE_DESIRED_STATES } from 'ee/workspaces/common/constants';
import {
  USER_WORKSPACES_LIST_QUERY_RESULT,
  GET_PROJECTS_DETAILS_QUERY_RESULT,
} from '../../../mock_data';

jest.mock('~/lib/logger');

Vue.use(VueApollo);

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';

const findTable = (wrapper) => wrapper.findComponent(GlTableLite);
const findTableRows = (wrapper) => findTable(wrapper).findAll('tbody tr');
const findTableRowsAsData = (wrapper) =>
  findTableRows(wrapper).wrappers.map((x) => {
    const tds = x.findAll('td');
    const rowData = {
      workspaceState: tds.at(0).findComponent(WorkspaceStateIndicator).props('workspaceState'),
      nameText: tds.at(1).text(),
      createdAt: tds.at(2).findComponent(TimeAgoTooltip).props().time,
      actionsProps: tds.at(5).findComponent(WorkspaceActions).props(),
    };

    const td3 = tds.at(3);
    const devfileLink = td3.findComponent(GlLink);
    if (devfileLink.exists()) {
      rowData.devfileText = td3.text();
      rowData.devfileHref = devfileLink.attributes('href');
      rowData.devfileTooltipTitle = devfileLink.attributes('title');
      rowData.devfileTooltipAriaLabel = devfileLink.attributes('aria-label');
    }

    if (tds.at(4).findComponent(GlLink).exists()) {
      rowData.previewText = tds.at(4).text();
      rowData.previewHref = tds.at(4).findComponent(GlLink).attributes('href');
    }

    return rowData;
  });
const findWorkspaceActions = (tableRow) => tableRow.findComponent(WorkspaceActions);

describe('workspaces/common/components/workspaces_list/workspaces_table.vue', () => {
  let wrapper;
  let updateWorkspaceMutationMock;
  const UpdateWorkspaceMutationStub = {
    render() {
      return this.$scopedSlots.default({ update: updateWorkspaceMutationMock });
    },
  };

  const createWrapper = ({
    workspaces = populateWorkspacesWithProjectDetails(
      USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
      GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
    ),
  } = {}) => {
    updateWorkspaceMutationMock = jest.fn();
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mount(WorkspacesTable, {
      provide: {
        emptyStateSvgPath: SVG_PATH,
      },
      propsData: {
        workspaces,
      },
      stubs: {
        UpdateWorkspaceMutation: UpdateWorkspaceMutationStub,
      },
    });
  };
  const setupMockTerminatedWorkspace = (extraData = {}) => {
    const customData = cloneDeep(
      USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
    );
    const workspace = cloneDeep(customData[0]);

    customData.unshift({
      ...workspace,
      actualState: WORKSPACE_STATES.terminated,
      ...extraData,
    });

    return customData;
  };
  const findUpdateWorkspaceMutation = () => wrapper.findComponent(UpdateWorkspaceMutationStub);

  describe('default (with nodes)', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows table when workspaces are available', () => {
      expect(findTable(wrapper).exists()).toBe(true);
    });

    it('displays user workspaces correctly', () => {
      expect(findTableRowsAsData(wrapper)).toEqual(
        populateWorkspacesWithProjectDetails(
          USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
          GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
        ).map((x) => {
          return {
            nameText: `${x.projectName}   ${x.name}`,
            workspaceState: x.actualState,
            createdAt: x.createdAt,
            actionsProps: {
              actualState: x.actualState,
              desiredState: x.desiredState,
              compact: false,
            },
            devfileText: `${x.devfilePath} on ${x.devfileRef}`,
            devfileHref: x.devfileWebUrl,
            devfileTooltipTitle: x.devfileWebUrl,
            ...(x.actualState === WORKSPACE_STATES.running
              ? {
                  previewText: x.url,
                  previewHref: x.url,
                }
              : {}),
          };
        }),
      );
    });

    describe('when the query returns terminated workspaces', () => {
      beforeEach(() => {
        createWrapper({ workspaces: setupMockTerminatedWorkspace() });
      });

      it('sorts the list to display terminated workspaces at the end of the list', () => {
        expect(findTableRowsAsData(wrapper).pop().workspaceState).toBe(WORKSPACE_STATES.terminated);
      });
    });
  });

  describe.each`
    event              | payload
    ${'updateFailed'}  | ${['error message']}
    ${'updateSucceed'} | ${[]}
  `('when updateWorspaceMutation triggers $event event', ({ event, payload }) => {
    it('bubbles up event', () => {
      createWrapper();

      expect(wrapper.emitted(event)).toBe(undefined);

      findUpdateWorkspaceMutation().vm.$emit(event, payload[0]);

      expect(wrapper.emitted(event)).toEqual([payload]);
    });
  });

  describe('workspace actions is clicked', () => {
    const TEST_WORKSPACE_IDX = 1;
    const TEST_DESIRED_STATE = WORKSPACE_DESIRED_STATES.terminated;
    let workspace;
    let workspaceActions;
    beforeEach(() => {
      createWrapper();
      const row = findTableRows(wrapper).at(TEST_WORKSPACE_IDX);
      workspace =
        USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes[TEST_WORKSPACE_IDX];
      workspaceActions = findWorkspaceActions(row);

      workspaceActions.vm.$emit('click', TEST_DESIRED_STATE);
    });

    it('calls the update method provided by the WorkspaceUpdateMutation component', () => {
      expect(updateWorkspaceMutationMock).toHaveBeenCalledWith(workspace.id, {
        desiredState: TEST_DESIRED_STATE,
      });
    });
  });
});
