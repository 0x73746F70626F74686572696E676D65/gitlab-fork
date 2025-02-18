<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import isEmpty from 'lodash/isEmpty';
import Connection from '~/integrations/edit/components/sections/connection.vue';
import { s__ } from '~/locale';
import { STATE_FORM, STATE_MANUAL } from '../google_cloud_iam/constants';
import GcIamForm from '../google_cloud_iam/form.vue';
import ManualSetup from '../google_cloud_iam/manual_setup.vue';
import SetupScript from '../google_cloud_iam/setup_script.vue';

const DEFAULT_DATA = {
  googleProjectId: '<your_google_cloud_project_id>',
  identityPoolId: '<your_identity_pool_id>',
  identityProviderId: '<your_identity_provider_id>',
};

export default {
  name: 'IntegrationSectionGoogleCloudIAM',
  components: {
    GcIamForm,
    ManualSetup,
    SetupScript,
    Connection,
  },
  data() {
    return { ...DEFAULT_DATA };
  },
  computed: {
    ...mapGetters(['propsSource']),
    wlifIssuer() {
      return this.propsSource.wlifIssuer;
    },
    jwtClaims() {
      return this.propsSource.jwtClaims;
    },
    dynamicFields() {
      return this.propsSource.fields;
    },
    helpTextPoolId() {
      return this.identityPoolId === DEFAULT_DATA.identityPoolId
        ? this.suggestedPoolId
        : this.identityPoolId;
    },
    integrationLevel() {
      return this.propsSource.integrationLevel;
    },
    suggestedPoolId() {
      const prefix = `gitlab-${this.propsSource.integrationLevel}`;

      if (this.propsSource.integrationLevel === 'project')
        return `${prefix}-${this.propsSource.projectId}`;

      if (this.propsSource.integrationLevel === 'group')
        return `${prefix}-${this.propsSource.groupId}`;

      // should not be possible; this integration is not instance-level
      return prefix;
    },
    projectOrGroupIDPrefix() {
      return this.integrationLevel === 'project'
        ? s__('GoogleCloud|GitLab project ID')
        : s__('GoogleCloud|GitLab group ID');
    },
    suggestedDisplayName() {
      const prefix = `GitLab ${this.propsSource.integrationLevel} ID`;

      if (this.propsSource.integrationLevel === 'project')
        return `${prefix} ${this.propsSource.projectId}`;

      if (this.propsSource.integrationLevel === 'group')
        return `${prefix} ${this.propsSource.groupId}`;

      // should not be possible; this integration is not instance-level
      return prefix;
    },
    isEditable() {
      return [STATE_FORM, STATE_MANUAL].includes(this.show);
    },
  },
  watch: {
    'this.propsSource.fields': {
      handler() {
        this.propsSource.fields.forEach(({ name, value }) => this.updateValue(name, value));
      },
      immediate: true,
    },
  },
  methods: {
    formUpdated({ field, value }) {
      this.updateValue(field.name, value);
    },
    updateValue(fieldName, fieldValue) {
      if (fieldName === 'workload_identity_federation_project_id') {
        this.googleProjectId = isEmpty(fieldValue) ? DEFAULT_DATA.googleProjectId : fieldValue;
      } else if (fieldName === 'workload_identity_pool_id') {
        this.identityPoolId = isEmpty(fieldValue) ? DEFAULT_DATA.identityPoolId : fieldValue;
      } else if (fieldName === 'workload_identity_pool_provider_id') {
        this.identityProviderId = isEmpty(fieldValue)
          ? DEFAULT_DATA.identityProviderId
          : fieldValue;
      }
    },
  },
};
</script>

<template>
  <div aria-live="polite" data-testid="google-cloud-iam-component">
    <connection />

    <manual-setup :wlif-issuer="wlifIssuer" :help-text-pool-id="helpTextPoolId" />

    <gc-iam-form
      :fields="dynamicFields"
      :suggested-pool-id="suggestedPoolId"
      :integration-level="integrationLevel"
      @update="formUpdated"
    />

    <setup-script
      :wlif-issuer="wlifIssuer"
      :google-project-id="googleProjectId"
      :identity-pool-id="identityPoolId"
      :identity-provider-id="identityProviderId"
      :jwt-claims="jwtClaims"
      :suggested-display-name="suggestedDisplayName"
    />
  </div>
</template>
