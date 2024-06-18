<script>
import { GlAlert, GlButton, GlForm, GlLoadingIcon, GlTooltip } from '@gitlab/ui';

import { convertToGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import { SAVE_ERROR } from 'ee/groups/settings/compliance_frameworks/constants';
import {
  getSubmissionParams,
  initialiseFormData,
} from 'ee/groups/settings/compliance_frameworks/utils';

import createComplianceFrameworkMutation from '../../../graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from '../../../graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from '../../../graphql/mutations/delete_compliance_framework.mutation.graphql';
import getComplianceFrameworkQuery from './graphql/get_compliance_framework.query.graphql';

import DeleteModal from './components/delete_modal.vue';
import BasicInformationSection from './components/basic_information_section.vue';
import PoliciesSection from './components/policies_section.vue';

import { i18n } from './constants';

export default {
  components: {
    BasicInformationSection,
    PoliciesSection,

    DeleteModal,

    GlAlert,
    GlButton,
    GlForm,
    GlLoadingIcon,
    GlTooltip,
  },
  inject: ['pipelineConfigurationFullPathEnabled', 'groupPath', 'featureSecurityPoliciesEnabled'],
  data() {
    return {
      errorMessage: '',
      formData: initialiseFormData(),
      originalName: '',
      isBasicInformationValid: true,
      isSaving: false,
      isDeleting: false,
    };
  },
  apollo: {
    namespace: {
      query: getComplianceFrameworkQuery,
      variables() {
        return {
          fullPath: this.groupPath,
          complianceFramework: this.graphqlId,
        };
      },
      result({ data }) {
        const [complianceFramework] = data?.namespace.complianceFrameworks?.nodes || [];
        if (complianceFramework) {
          this.formData = { ...complianceFramework };
          this.originalName = complianceFramework.name;
        } else {
          this.errorMessage = this.$options.i18n.fetchError;
        }
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
      skip() {
        return this.isNewFramework;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading || this.isSaving;
    },

    isNewFramework() {
      return !this.$route.params.id;
    },

    hasLinkedPolicies() {
      return Boolean(
        this.formData.scanResultPolicies?.pageInfo.startCursor ||
          this.formData.scanExecutionPolicies?.pageInfo.startCursor,
      );
    },

    deleteBtnDisabled() {
      return this.hasLinkedPolicies;
    },

    deleteBtnDisabledTooltip() {
      return i18n.deleteButtonDisabledTooltip;
    },

    refetchConfig() {
      return {
        awaitRefetchQueries: true,
        refetchQueries: [
          {
            query: getComplianceFrameworkQuery,
            variables: {
              fullPath: this.groupPath,
            },
          },
        ],
      };
    },

    title() {
      return this.isNewFramework
        ? this.$options.i18n.addFrameworkTitle
        : this.$options.i18n.editFrameworkTitle;
    },

    saveButtonText() {
      return this.isNewFramework
        ? this.$options.i18n.addSaveBtnText
        : this.$options.i18n.editSaveBtnText;
    },

    graphqlId() {
      return this.$route.params.id
        ? convertToGraphQLId('ComplianceManagement::Framework', this.$route.params.id)
        : null;
    },

    disableSubmitBtn() {
      return !this.isBasicInformationValid;
    },

    shouldRenderPolicySection() {
      return !this.isNewFramework && this.featureSecurityPoliciesEnabled;
    },
  },

  methods: {
    setError(error, userFriendlyText) {
      this.isSaving = false;
      this.errorMessage = userFriendlyText;
      Sentry.captureException(error);
    },

    onCancel() {
      this.$router.back();
    },

    async onSubmit() {
      this.isSaving = true;
      this.errorMessage = '';
      try {
        const params = getSubmissionParams(
          this.formData,
          this.pipelineConfigurationFullPathEnabled,
        );

        const mutation = this.isNewFramework
          ? createComplianceFrameworkMutation
          : updateComplianceFrameworkMutation;
        const extraInput = this.isNewFramework
          ? { namespacePath: this.groupPath }
          : { id: this.graphqlId };
        const { data } = await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              ...extraInput,
              params,
            },
          },
          ...this.refetchConfig,
        });

        const [error] = data?.createComplianceFramework?.errors || [];

        if (error) {
          this.setError(new Error(error), error);
        } else {
          this.$router.back();
        }
      } catch (e) {
        this.setError(e, SAVE_ERROR);
      }
    },

    async deleteFramework() {
      this.isDeleting = true;

      try {
        const {
          data: { destroyComplianceFramework },
        } = await this.$apollo.mutate({
          mutation: deleteComplianceFrameworkMutation,
          variables: {
            input: {
              id: this.graphqlId,
            },
          },
          ...this.refetchConfig,
        });

        const [error] = destroyComplianceFramework.errors;

        if (error) {
          throw error;
        }
        this.$router.back();
      } catch (error) {
        this.fetchError = error;
        Sentry.captureException(error);
      }
    },

    onDelete() {
      this.$refs.deleteModal.show();
    },
  },

  i18n,
};
</script>

<template>
  <div class="gl-border-t-1 gl-border-t-solid gl-border-t-gray-100 gl-pt-5">
    <gl-alert v-if="errorMessage" class="gl-mb-5" variant="danger" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>
    <gl-loading-icon v-if="isLoading" size="lg" />

    <template v-else>
      <h2>{{ title }}</h2>
      <gl-form @submit.prevent="onSubmit">
        <basic-information-section
          v-if="formData"
          v-model="formData"
          :expandable="!isNewFramework"
          @valid="isBasicInformationValid = $event"
        />

        <policies-section
          v-if="shouldRenderPolicySection"
          :full-path="groupPath"
          :graphql-id="graphqlId"
        />

        <div class="gl-display-flex gl-pt-5 gl-gap-3">
          <gl-button
            type="submit"
            variant="confirm"
            class="js-no-auto-disable"
            data-testid="submit-btn"
            :disabled="disableSubmitBtn"
          >
            {{ saveButtonText }}
          </gl-button>
          <gl-button data-testid="cancel-btn" @click="onCancel">{{ __('Cancel') }}</gl-button>
          <template v-if="graphqlId">
            <gl-tooltip
              v-if="deleteBtnDisabled"
              :target="() => $refs.deleteBtn"
              :title="deleteBtnDisabledTooltip"
            />
            <div ref="deleteBtn" class="gl-ml-auto">
              <gl-button
                variant="danger"
                data-testid="delete-btn"
                :loading="isDeleting"
                :disabled="deleteBtnDisabled"
                @click="onDelete"
              >
                {{ $options.i18n.deleteButtonText }}
              </gl-button>
            </div>
          </template>
        </div>
      </gl-form>
    </template>

    <delete-modal
      v-if="graphqlId"
      ref="deleteModal"
      :name="originalName"
      @delete="deleteFramework"
    />
  </div>
</template>
