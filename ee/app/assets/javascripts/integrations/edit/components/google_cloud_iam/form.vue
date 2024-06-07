<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import Configuration from '~/integrations/edit/components/sections/configuration.vue';
import Connection from '~/integrations/edit/components/sections/connection.vue';

export default {
  name: 'GoogleCloudIAMForm',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    Configuration,
    Connection,
  },
  props: {
    fields: {
      type: Array,
      required: true,
    },
  },
  computed: {
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
    <connection />

    <h4 class="gl-mt-0">{{ s__('GoogleCloud|Google Cloud project') }}</h4>
    <p>
      <gl-sprintf
        :message="
          s__(
            'GoogleCloud|Identify the Google Cloud project with the workload identity pool and provider. %{linkStart}Where are my project ID and project number?%{linkEnd}',
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
      field-class="gl-form-input-lg gl-flex-grow-1"
      class="gl-border-b gl-mb-6 sm:gl-flex gl-flex-direction-row gl-gap-5"
    />

    <h4 class="gl-mt-0">{{ s__('GoogleCloud|Workload identity federation') }}</h4>
    <p>
      {{
        s__(
          'GoogleCloud|Connect to Google Cloud with workload identity federation for secure access without accounts or keys.',
        )
      }}
    </p>

    <configuration
      :fields="workloadIdentityFields"
      field-class="gl-form-input-lg gl-flex-grow-1"
      class="gl-mb-6 sm:gl-flex gl-flex-direction-row gl-gap-5"
    />
  </div>
</template>
