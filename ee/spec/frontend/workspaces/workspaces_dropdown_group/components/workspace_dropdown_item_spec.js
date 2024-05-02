import { GlDisclosureDropdownItem } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkspaceStateIndicator from 'ee/workspaces/common/components/workspace_state_indicator.vue';
import WorkspaceActions from 'ee/workspaces/common/components/workspace_actions.vue';
import { WORKSPACE_DESIRED_STATES } from 'ee/workspaces/dropdown_group/constants';
import WorkspaceDropdownItem from 'ee/workspaces/dropdown_group/components/workspace_dropdown_item.vue';
import { WORKSPACE } from '../../mock_data';

describe('workspaces/dropdown_group/components/workspace_dropdown_item.vue', () => {
  let wrapper;
  let trackingSpy;

  const createWrapper = () => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMountExtended(WorkspaceDropdownItem, {
      propsData: {
        workspace: WORKSPACE,
      },
    });

    trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
  };
  const findWorkspaceStateIndicator = () => wrapper.findComponent(WorkspaceStateIndicator);
  const findWorkspaceActions = () => wrapper.findComponent(WorkspaceActions);
  const findDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays workspace state indicator', () => {
      expect(findWorkspaceStateIndicator().props().workspaceState).toBe(WORKSPACE.actualState);
    });

    it('displays the workspace name', () => {
      expect(wrapper.text()).toContain(WORKSPACE.name);
    });

    it('displays workspace creation date', () => {
      expect(wrapper.findComponent(TimeAgoTooltip).props('time')).toBe(WORKSPACE.createdAt);
    });

    it('passes workspace URL to the dropdown item', () => {
      expect(findDropdownItem().props().item).toEqual({
        text: WORKSPACE.name,
        href: WORKSPACE.url,
      });
    });

    it('displays workspace actions', () => {
      expect(findWorkspaceActions().props()).toEqual({
        actualState: WORKSPACE.actualState,
        desiredState: WORKSPACE.desiredState,
        compact: true,
      });
    });
  });

  describe('when the dropdown item emits "action" event', () => {
    beforeEach(() => {
      createWrapper();

      findDropdownItem().vm.$emit('action');
    });

    it('tracks event', () => {
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_consolidated_edit', {
        label: 'workspace',
      });
    });
  });

  describe('when workspaces action is clicked', () => {
    it('emits updateWorkspace event with the desiredState provided by the action', () => {
      createWrapper();

      expect(wrapper.emitted('updateWorkspace')).toBe(undefined);

      findWorkspaceActions().vm.$emit('click', WORKSPACE_DESIRED_STATES.running);

      expect(wrapper.emitted('updateWorkspace')).toEqual([
        [{ desiredState: WORKSPACE_DESIRED_STATES.running }],
      ]);
    });
  });
});
