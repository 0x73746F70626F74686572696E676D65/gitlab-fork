<script>
import { GlButton, GlForm, GlFormGroup, GlFormInput, GlIcon, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import AddPipelineSubscription from '../graphql/mutations/add_pipeline_subscription.mutation.graphql';

export default {
  name: 'PipelineSubscriptionsForm',
  i18n: {
    formLabel: __('Project path'),
    inputPlaceholder: __('Paste project path (i.e. gitlab-org/gitlab)'),
    subscribe: __('Subscribe'),
    cancel: __('Cancel'),
    addSubscription: s__('PipelineSubscriptions|Add new pipeline subscription'),
    generalError: s__(
      'PipelineSubscriptions|An error occurred while adding a new pipeline subscription.',
    ),
    addSuccess: s__('PipelineSubscriptions|Subscription successfully added.'),
  },
  docsLink: helpPagePath('ci/pipelines/index', {
    anchor: 'trigger-a-pipeline-when-an-upstream-project-is-rebuilt',
  }),
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlLink,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  data() {
    return {
      upstreamPath: '',
    };
  },
  methods: {
    async createSubscription() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: AddPipelineSubscription,
          variables: {
            input: {
              projectPath: this.projectPath,
              upstreamPath: this.upstreamPath,
            },
          },
        });

        if (data.projectSubscriptionCreate.errors.length > 0) {
          createAlert({ message: data.projectSubscriptionCreate.errors[0] });
        } else {
          createAlert({ message: this.$options.i18n.addSuccess, variant: 'success' });
          this.upstreamPath = '';

          this.$emit('addSubscriptionSuccess');
        }
      } catch (error) {
        const { graphQLErrors } = error;

        if (graphQLErrors.length > 0) {
          createAlert({ message: graphQLErrors[0]?.message, variant: 'warning' });
        } else {
          createAlert({ message: this.$options.i18n.generalError });
        }
      }
    },
    cancelSubscription() {
      this.upstreamPath = '';
      this.$emit('canceled');
    },
  },
};
</script>

<template>
  <div class="gl-new-card-add-form gl-m-3">
    <h4 class="gl-mt-0">{{ $options.i18n.addSubscription }}</h4>
    <gl-form>
      <gl-form-group label-for="project-path">
        <template #label>
          {{ $options.i18n.formLabel }}
          <gl-link :href="$options.docsLink" target="_blank">
            <gl-icon class="gl-text-blue-600" name="question-o" />
          </gl-link>
        </template>
        <gl-form-input
          id="project-path"
          v-model="upstreamPath"
          type="text"
          :placeholder="$options.i18n.inputPlaceholder"
          data-testid="upstream-project-path-field"
        />
      </gl-form-group>

      <gl-button variant="confirm" data-testid="subscribe-button" @click="createSubscription">
        {{ $options.i18n.subscribe }}
      </gl-button>
      <gl-button class="gl-ml-3" data-testid="cancel-button" @click="cancelSubscription">
        {{ $options.i18n.cancel }}
      </gl-button>
    </gl-form>
  </div>
</template>
