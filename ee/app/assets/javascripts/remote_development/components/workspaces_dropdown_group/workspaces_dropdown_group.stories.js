import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlDisclosureDropdown } from '@gitlab/ui';
import { withGitLabAPIAccess } from 'storybook_addons/gitlab_api_access';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import WorkspacesDropdownGroup from './workspaces_dropdown_group.vue';

Vue.use(VueApollo);

export default {
  component: WorkspacesDropdownGroup,
  title: 'ee/remote_development/workspaces_dropdown_group',
};

export const WithAPIAccess = (args, { argTypes, createVueApollo }) => {
  return {
    components: { WorkspacesDropdownGroup, GlDisclosureDropdown },
    apolloProvider: createVueApollo(),
    provide: {
      projectId: convertToGraphQLId('Project', args.projectId),
    },
    props: Object.keys(argTypes),
    template: `<gl-disclosure-dropdown fluid-width toggle-text="Edit">
      <workspaces-dropdown-group />
    </gl-disclosure-dropdown>`,
  };
};

WithAPIAccess.decorators = [withGitLabAPIAccess];
WithAPIAccess.args = {
  projectId: '',
};
