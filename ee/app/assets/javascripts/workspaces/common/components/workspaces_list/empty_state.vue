<script>
import { GlEmptyState, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';

export const i18n = {
  title: s__('Workspaces|Develop anywhere'),
  description:
    s__(`Workspaces|GitLab Workspaces is a powerful collaborative platform that provides a
                      comprehensive set of tools for software development
                      teams to manage their entire development lifecycle.`),
  primaryButtonText: s__('Workspaces|New workspace'),
};

export default {
  components: {
    GlEmptyState,
    GlButton,
  },
  inject: ['emptyStateSvgPath'],
  props: {
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  i18n,
};
</script>

<template>
  <div>
    <gl-empty-state
      :title="$options.i18n.title"
      :description="$options.i18n.description"
      :svg-path="emptyStateSvgPath"
      :svg-height="150"
    >
      <template v-if="newWorkspacePath" #actions>
        <gl-button
          variant="confirm"
          class="gl-mb-3 gl-mx-2"
          :to="newWorkspacePath"
          data-testid="new-workspace-button"
          >{{ $options.i18n.primaryButtonText }}</gl-button
        >
      </template>
    </gl-empty-state>
  </div>
</template>
