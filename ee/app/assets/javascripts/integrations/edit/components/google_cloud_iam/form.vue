<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import { s__ } from '~/locale';

export default {
  name: 'GoogleCloudIAMForm',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    Configuration,
  },
  props: {
    fields: {
      type: Array,
      required: true,
    },
    suggestedPoolId: {
      type: String,
      required: false,
      default: 'gitlab-wlif',
    },
    integrationLevel: {
      type: String,
      required: false,
      default: 'group',
    },
  },
  computed: {
    avoidCollisionMessage() {
      return this.integrationLevel === 'project'
        ? s__(
            'GoogleCloud|To avoid collisions, use unique IDs like this GitLab project ID: %{suggested}',
          )
        : s__(
            'GoogleCloud|To avoid collisions, use unique IDs like this GitLab group ID: %{suggested}',
          );
    },
    gcProjectFields() {
      return this.fields.filter((field) => field.name.includes('workload_identity_federation'));
    },
    workloadIdentityFields() {
      return this.fields.filter((field) => field.name.includes('workload_identity_pool'));
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-mt-0">{{ s__('GoogleCloud|Google Cloud project') }}</h4>
    <p>
      <gl-sprintf
        :message="
          s__(
            'GoogleCloud|Project for the workload identity pool and provider. %{linkStart}Where are my project ID and project number?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link
            href="https://cloud.google.com/resource-manager/docs/creating-managing-projects#identifying_projects"
            target="_blank"
            >{{ content }}
            <gl-icon name="external-link" :aria-label="__('(external link)')" />
          </gl-link>
        </template>
      </gl-sprintf>
    </p>

    <configuration
      :fields="gcProjectFields"
      field-class="gl-flex-grow-1 gl-flex-basis-0"
      class="gl-mb-6 md:gl-flex gl-flex-direction-row gl-gap-5"
      v-on="$listeners"
    />

    <h4 class="gl-mt-0">{{ s__('GoogleCloud|Workload identity federation') }}</h4>
    <p>
      <gl-sprintf :message="avoidCollisionMessage">
        <template #suggested>
          <code>{{ suggestedPoolId }}</code>
        </template>
      </gl-sprintf>
    </p>

    <configuration
      :fields="workloadIdentityFields"
      field-class="gl-flex-grow-1 gl-flex-basis-0"
      class="gl-mb-6 md:gl-flex gl-flex-direction-row gl-gap-5"
      v-on="$listeners"
    />

    <hr />
  </div>
</template>
