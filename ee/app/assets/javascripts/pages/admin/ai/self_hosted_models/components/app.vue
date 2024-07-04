<script>
import { GlEmptyState, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import EmptyLabelsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-labels-md.svg?url';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getSelfHostedModelsQuery from '../queries/get_self_hosted_models.query.graphql';
import SelfHostedModelsTable from './self_hosted_models_table.vue';

export default {
  name: 'SelfHostedModelsApp',
  components: {
    GlEmptyState,
    GlButton,
    GlSkeletonLoader,
    SelfHostedModelsTable,
  },
  props: {
    basePath: {
      type: String,
      required: true,
    },
    newSelfHostedModelPath: {
      type: String,
      required: true,
    },
  },
  i18n: {
    emptyStateTitle: s__('AdminSelfHostedModels|Define your set of self-hosted models'),
    emptyStateDescription: s__(
      'AdminSelfHostedModels|Add self-hosted language models to use as backups for GitLab Duo features.',
    ),
    emptyStatePrimaryButtonText: s__('AdminSelfHostedModels|New self-hosted model'),
    errorMessage: s__(
      'AdminSelfHostedModels|An error occurred while loading self-hosted models. Please try again.',
    ),
  },
  data() {
    return {
      selfHostedModels: [],
    };
  },
  apollo: {
    selfHostedModels: {
      query: getSelfHostedModelsQuery,
      update(data) {
        return data.aiSelfHostedModels?.nodes || [];
      },
      error(error) {
        createAlert({ message: this.$options.i18n.errorMessage, error, captureError: true });
      },
    },
  },
  computed: {
    hasModels() {
      return this.selfHostedModels.length > 0;
    },
    isLoading() {
      return this.$apollo?.queries?.selfHostedModels?.loading;
    },
  },
  emptyStateSvgPath: EmptyLabelsSvg,
};
</script>
<template>
  <div>
    <section>
      <h1 class="page-title gl-font-size-h-display">
        {{ s__('AdminSelfHostedModels|Self-hosted models') }}
      </h1>
      <div class="gl-flex gl-justify-between gl-items-top">
        <p>
          {{
            s__(
              'AdminSelfHostedModels|Self-hosted AI models can be used to power GitLab AI features.',
            )
          }}
        </p>
        <div v-if="hasModels" class="gl-pb-4">
          <gl-button
            category="primary"
            variant="confirm"
            size="small"
            :href="newSelfHostedModelPath"
            >{{ s__('AdminSelfHostedModels|New model') }}
          </gl-button>
        </div>
      </div>
    </section>
    <div v-if="!hasModels && !isLoading">
      <gl-empty-state
        :title="$options.i18n.emptyStateTitle"
        :description="$options.i18n.emptyStateDescription"
        :svg-path="$options.emptyStateSvgPath"
        :svg-height="150"
        :primary-button-text="$options.i18n.emptyStatePrimaryButtonText"
        :primary-button-link="newSelfHostedModelPath"
      />
    </div>
    <div v-else>
      <gl-skeleton-loader v-if="isLoading" />
      <self-hosted-models-table v-else :models="selfHostedModels" :base-path="basePath" />
    </div>
  </div>
</template>
