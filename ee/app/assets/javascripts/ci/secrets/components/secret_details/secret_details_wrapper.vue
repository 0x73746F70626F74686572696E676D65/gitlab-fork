<script>
import { GlAlert, GlButton, GlLabel, GlLoadingIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import { DETAILS_ROUTE_NAME, EDIT_ROUTE_NAME, SCOPED_LABEL_COLOR } from '../../constants';
import getSecretDetailsQuery from '../../graphql/queries/client/get_secret_details.query.graphql';
import SecretDetails from './secret_details.vue';

export default {
  name: 'SecretDetailsWrapper',
  components: {
    GlAlert,
    GlButton,
    GlLabel,
    GlLoadingIcon,
    SecretDetails,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    routeName: {
      type: String,
      required: true,
    },
    secretId: {
      type: Number,
      required: true,
    },
  },
  apollo: {
    secret: {
      skip() {
        return !this.secretId;
      },
      query: getSecretDetailsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          id: this.secretId,
        };
      },
      update(data) {
        return data.project?.secret || null;
      },
    },
  },
  data() {
    return {
      secret: null,
    };
  },
  computed: {
    createdAtText() {
      const { createdAt } = this.secret;
      const date = localeDateFormat.asDateTimeFull.format(createdAt);
      return sprintf(__('Created on %{date}'), { date });
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
    isSecretLoading() {
      return this.$apollo.queries.secret.loading;
    },
  },
  methods: {
    goToEdit() {
      this.$router.push({ name: EDIT_ROUTE_NAME, params: { id: this.secretId } });
    },
    goTo(name) {
      if (this.routeName !== name) {
        this.$router.push({ name });
      }
    },
  },
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  SCOPED_LABEL_COLOR,
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isSecretLoading" size="lg" class="gl-mt-6" />
    <!-- TODO: Update error handling when designs and API are available -->
    <!-- See: https://gitlab.com/gitlab-org/gitlab/-/issues/464683 -->
    <gl-alert v-else-if="!secret" variant="danger" :dismissible="false" class="gl-mt-3">
      {{ s__('Secrets|Failed to load secret. Please try again later.') }}
    </gl-alert>
    <div v-else>
      <div class="gl-flex gl-justify-between gl-items-center">
        <h1 class="page-title gl-text-size-h-display">{{ secret.key }}</h1>
        <div>
          <gl-button
            icon="pencil"
            :aria-label="__('Edit')"
            data-testid="secret-edit-button"
            @click="goToEdit"
          />
          <gl-button
            :aria-label="__('Revoke')"
            category="secondary"
            variant="danger"
            data-testid="secret-revoke-button"
          >
            {{ __('Revoke') }}
          </gl-button>
          <gl-button :aria-label="__('Delete')" variant="danger" data-testid="secret-delete-button">
            {{ __('Delete') }}
          </gl-button>
        </div>
      </div>
      <div class="gl-mb-4">
        <gl-label
          :title="environmentLabelText"
          :background-color="$options.SCOPED_LABEL_COLOR"
          scoped
        />
        <span class="gl-text-gray-500 gl-ml-3" data-testid="secret-created-at">
          {{ createdAtText }}
        </span>
      </div>
      <secret-details :secret="secret" />
    </div>
  </div>
</template>
