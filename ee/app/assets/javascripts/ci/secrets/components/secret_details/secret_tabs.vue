<script>
import { GlAlert, GlButton, GlLabel, GlLoadingIcon, GlTabs, GlTab } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import {
  AUDIT_LOG_ROUTE_NAME,
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  SCOPED_LABEL_COLOR,
} from '../../constants';
import getSecretDetailsQuery from '../../graphql/queries/client/get_secret_details.query.graphql';

export default {
  name: 'SecretTabs',
  components: {
    GlAlert,
    GlButton,
    GlLabel,
    GlLoadingIcon,
    GlTabs,
    GlTab,
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
    tabIndex() {
      return this.routeName === AUDIT_LOG_ROUTE_NAME ? 1 : 0;
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
  AUDIT_LOG_ROUTE_NAME,
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
      <gl-tabs :value="tabIndex">
        <gl-tab @click="goTo($options.DETAILS_ROUTE_NAME)">
          <template #title>{{ s__('Secrets|Details') }}</template>
        </gl-tab>
        <gl-tab @click="goTo($options.AUDIT_LOG_ROUTE_NAME)">
          <template #title>{{ s__('Secrets|Audit log') }}</template>
        </gl-tab>
        <router-view :secret="secret" />
      </gl-tabs>
    </div>
  </div>
</template>
