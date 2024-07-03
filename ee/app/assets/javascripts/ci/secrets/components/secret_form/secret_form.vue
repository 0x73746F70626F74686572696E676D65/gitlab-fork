<script>
import {
  GlButton,
  GlCollapsibleListbox,
  GlDatepicker,
  GlDropdownDivider,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { isDate } from 'lodash';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import { INDEX_ROUTE_NAME, DETAILS_ROUTE_NAME, ROTATION_PERIOD_OPTIONS } from '../../constants';
import { convertRotationPeriod } from '../../utils';
import CreateSecretMutation from '../../graphql/mutations/client/create_secret.mutation.graphql';
import SecretPreviewModal from './secret_preview_modal.vue';

export default {
  name: 'SecretForm',
  components: {
    CiEnvironmentsDropdown,
    GlButton,
    GlCollapsibleListbox,
    GlDropdownDivider,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlLink,
    GlSprintf,
    SecretPreviewModal,
  },
  props: {
    areEnvironmentsLoading: {
      type: Boolean,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    fullPath: {
      type: String,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      customRotationPeriod: '',
      isPreviewing: false,
      isSubmitting: false,
      secret: {
        createdAt: undefined,
        environment: '*',
        expiration: undefined,
        description: '',
        key: undefined,
        rotationPeriod: '',
        value: undefined,
      },
    };
  },
  computed: {
    canSubmit() {
      if (this.isExpirationValid && this.isKeyValid && this.isValueValid) {
        return true;
      }

      return false;
    },
    createdAt() {
      return this.secret.createdAt || Date.now();
    },
    isExpirationValid() {
      return isDate(this.secret.expiration);
    },
    isKeyValid() {
      return this.secret.key.length > 0;
    },
    isValueValid() {
      return this.secret.value.length > 0;
    },
    minExpirationDate() {
      // secrets can expire tomorrow, but not today or yesterday
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    rotationPeriodText() {
      return convertRotationPeriod(this.secret.rotationPeriod);
    },
    rotationPeriodToggleText() {
      if (this.secret.rotationPeriod.length) {
        return this.rotationPeriodText;
      }

      return s__('Secrets|Select a rotation interval');
    },
  },
  methods: {
    async createSecret() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: CreateSecretMutation,
          variables: {
            fullPath: this.fullPath,
            secret: this.secret,
          },
        });

        this.isSubmitting = false;

        const { errors } = data.createSecret || [];
        if (errors.length > 0) {
          createAlert({ message: errors[0] });
        } else {
          const { secret } = data.createSecret;
          this.$router.push({ name: DETAILS_ROUTE_NAME, params: { id: secret.id } });
        }
      } catch (e) {
        this.isSubmitting = false;
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      }
    },
    editSecret() {
      // TODO
    },
    hidePreviewModal() {
      this.isPreviewing = false;
    },
    setCustomRotationPeriod() {
      this.secret.rotationPeriod = this.customRotationPeriod.trim();
    },
    setEnvironment(environment) {
      this.secret = { ...this.secret, environment };
    },
    showPreviewModal() {
      if (this.canSubmit) {
        this.isPreviewing = true;
      }
    },
    async submitSecret() {
      if (this.isEditing) {
        await this.editSecret();
      } else {
        await this.createSecret();
      }
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  cronPlaceholder: '0 6 * * *',
  i18n: {
    fieldRequired: __('This field is required'),
  },
  rotationPeriodOptions: ROTATION_PERIOD_OPTIONS,
  secretsIndexRoute: INDEX_ROUTE_NAME,
};
</script>
<template>
  <div>
    <gl-form @submit.prevent="showPreviewModal">
      <gl-form-group
        data-testid="secret-key-field-group"
        label-for="secret-key"
        :label="s__('Secrets|Secret key')"
        :invalid-feedback="$options.i18n.fieldRequired"
        :state="secret.key === undefined || isKeyValid"
      >
        <gl-form-input
          id="secret-key"
          v-model="secret.key"
          :placeholder="s__('Secrets|Enter a key name')"
          :state="secret.key === undefined || isKeyValid"
        />
      </gl-form-group>
      <gl-form-group
        data-testid="secret-value-field-group"
        label-for="secret-value"
        :label="s__('Secrets|Value')"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <gl-form-textarea
          id="secret-value"
          v-model="secret.value"
          rows="5"
          max-rows="15"
          no-resize
          :placeholder="s__('Secrets|Value for the key')"
          :spellcheck="false"
          :state="secret.value === undefined || isValueValid"
        />
      </gl-form-group>
      <gl-form-group :label="__('Description')" label-for="secret-description" optional>
        <gl-form-input
          id="secret-description"
          v-model="secret.description"
          data-testid="secret-description"
          :placeholder="s__('Secrets|Add a description for the secret')"
        />
      </gl-form-group>
      <gl-form-group
        :label="s__('Secrets|Select environment')"
        label-for="secret-environment"
        class="gl-w-1/2 gl-pr-2"
      >
        <ci-environments-dropdown
          :are-environments-loading="areEnvironmentsLoading"
          :environments="environments"
          :is-environment-required="false"
          :selected-environment-scope="secret.environment"
          @select-environment="setEnvironment"
          @search-environment-scope="$emit('search-environment', $event)"
        />
      </gl-form-group>
      <div class="gl-display-flex gl-gap-4">
        <gl-form-group
          class="gl-w-full"
          label-for="secret-expiration"
          :label="s__('Secrets|Set expiration')"
        >
          <gl-datepicker
            id="secret-expiration"
            v-model="secret.expiration"
            class="gl-max-w-none"
            :placeholder="$options.datePlaceholder"
            :min-date="minExpirationDate"
          />
        </gl-form-group>
        <gl-form-group
          class="gl-w-full"
          :label="s__('Secrets|Rotation period')"
          label-for="secret-rotation-period"
          optional
        >
          <gl-collapsible-listbox
            id="secret-rotation-period"
            v-model="secret.rotationPeriod"
            block
            :label-text="s__('Secrets|Rotation period')"
            :header-text="s__('Secrets|Intervals')"
            :toggle-text="rotationPeriodToggleText"
            :items="$options.rotationPeriodOptions"
          >
            <template #footer>
              <gl-dropdown-divider />
              <div class="gl-mt-3 gl-mb-4 gl-mx-3">
                <p class="gl-py-0 gl-my-0">{{ s__('Secrets|Add custom interval.') }}</p>
                <p class="gl-py-0 gl-my-0 gl-font-sm gl-text-secondary">
                  <gl-sprintf :message="__('Use CRON syntax. %{linkStart}Learn more.%{linkEnd}')">
                    <template #link="{ content }">
                      <gl-link href="https://crontab.guru/" target="_blank">{{ content }}</gl-link>
                    </template>
                  </gl-sprintf>
                </p>
                <gl-form-input
                  v-model="customRotationPeriod"
                  data-testid="secret-cron"
                  :placeholder="$options.cronPlaceholder"
                  class="gl-my-3"
                />
                <gl-button
                  class="gl-float-right"
                  data-testid="add-custom-rotation-button"
                  size="small"
                  variant="confirm"
                  :aria-label="__('Add interval')"
                  @click="setCustomRotationPeriod"
                >
                  {{ __('Add interval') }}
                </gl-button>
              </div>
            </template>
          </gl-collapsible-listbox>
        </gl-form-group>
      </div>
      <!-- TODO: Access permission fields will be added in a future iteration -->
      <!-- See: https://gitlab.com/gitlab-org/gitlab/-/issues/457380 -->
      <gl-form-group label-for="secret-roles-and-users" :label="__('Access permission')">
        <div class="gl-display-flex gl-gap-4">
          <gl-form-input :placeholder="__('Select roles or users')" disabled />
          <gl-form-input :placeholder="__('Select permission')" disabled />
        </div>
      </gl-form-group>
      <div class="gl-my-3">
        <gl-button
          variant="confirm"
          data-testid="submit-form-button"
          :aria-label="__('Continue')"
          :disabled="!canSubmit || isSubmitting"
          :loading="isSubmitting"
          @click="showPreviewModal"
        >
          {{ __('Continue') }}
        </gl-button>
        <gl-button
          :to="{ name: $options.secretsIndexRoute }"
          data-testid="cancel-button"
          class="gl-my-4"
          :aria-label="__('Cancel')"
          :disabled="isSubmitting"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </gl-form>
    <secret-preview-modal
      :created-at="createdAt"
      :description="secret.description"
      :environment="secret.environment"
      :expiration="secret.expiration"
      :is-editing="isEditing"
      :is-visible="isPreviewing"
      :secret-key="secret.key"
      :rotation-period="rotationPeriodText"
      @hide-preview-modal="hidePreviewModal"
      @submit-secret="submitSecret"
      v-on="$listeners"
    />
  </div>
</template>
