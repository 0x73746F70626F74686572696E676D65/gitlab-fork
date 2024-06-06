<script>
import { GlEmptyState } from '@gitlab/ui';
import EmptyLabelsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-labels-md.svg?url';
import { s__, __ } from '~/locale';

export default {
  name: 'CustomModelsApp',
  components: {
    GlEmptyState,
  },
  i18n: {
    emptyStateTitle: s__('AdminSelfHostedModels|Define your set of self-hosted models'),
    emptyStateDescription: s__(
      'AdminSelfHostedModels|They point to the self-hosted AI models that can be used for backing up GitLab AI features.',
    ),
    emptyStatePrimaryButtonText: __('New Self-Hosted Model'),
  },
  props: {
    models: {
      type: Array,
      required: true,
    },
  },
  computed: {
    hasModels() {
      return this.models.length > 0;
    },
  },
  emptyStateSvgPath: EmptyLabelsSvg,
};
</script>
<template>
  <div id="custom-models-app">
    <div v-for="model in models" :key="model.id">
      <!-- Design for each model entry in the listing -->
    </div>
    <div v-if="!hasModels">
      <gl-empty-state
        :title="$options.i18n.emptyStateTitle"
        :description="$options.i18n.emptyStateDescription"
        :svg-path="$options.emptyStateSvgPath"
        svg-height="150"
        :primary-button-text="$options.i18n.emptyStatePrimaryButtonText"
        primary-button-link="/admin/ai/self_hosted_models/new"
      />
    </div>
  </div>
</template>
