<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

export default {
  components: {
    CodeBlockHighlighted,
    ClipboardButton,
    GlIcon,
    GlLink,
    GlSprintf,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    ...mapGetters(['propsSource']),
    projectId() {
      return this.propsSource.projectId;
    },
    googleCloudProjectId() {
      return this.id || "'<your_google_cloud_project_id>'";
    },
    workloadIdentityFederationProjectNumber() {
      return this.propsSource.googleArtifactManagementProps
        ?.workloadIdentityFederationProjectNumber;
    },
    workloadIdentityPoolId() {
      return this.propsSource.googleArtifactManagementProps?.workloadIdentityPoolId;
    },
    instructions() {
      const workloadIdentityBasePath = `principalSet://iam.googleapis.com/projects/${this.workloadIdentityFederationProjectNumber}/locations/global/workloadIdentityPools/${this.workloadIdentityPoolId}`;

      return `# Grant the Artifact Registry Reader role to GitLab users with at least the Guest role
gcloud projects add-iam-policy-binding ${this.googleCloudProjectId} \\
  --member='${workloadIdentityBasePath}/attribute.guest_access/true' \\
  --role='roles/artifactregistry.reader'

# Grant the Artifact Registry Writer role to GitLab users with at least the Developer role
gcloud projects add-iam-policy-binding ${this.googleCloudProjectId} \\
  --member='${workloadIdentityBasePath}/attribute.developer_access/true' \\
  --role='roles/artifactregistry.writer'`;
    },
    hasId() {
      return Boolean(this.id);
    },
    claimsHelpURL() {
      return helpPagePath('integration/google_cloud_iam', {
        anchor: 'oidc-custom-claims',
      });
    },
  },
};
</script>

<template>
  <div class="gl-mb-5">
    <h3>
      {{ s__('GoogleArtifactRegistry|2. Set up permissions') }}
    </h3>
    <p>
      <gl-sprintf
        :message="
          s__(
            'GoogleArtifactRegistry|To use the integration, allow this GitLab project to read and write to Google Artifact Registry. You can use the following recommended setup or customize it with other %{claimsStart}OIDC custom claims%{claimsEnd} and %{rolesStart}Artifact Registry roles%{rolesEnd}.',
          )
        "
      >
        <template #claims="{ content }">
          <gl-link :href="claimsHelpURL" target="_blank">
            {{ content }}
          </gl-link>
        </template>
        <template #roles="{ content }">
          <gl-link
            href="https://cloud.google.com/artifact-registry/docs/access-control#roles"
            target="_blank"
          >
            {{ content }}
            <gl-icon name="external-link" :aria-label="__('(external link)')" />
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <ol>
      <li>
        <gl-sprintf
          :message="
            s__('GoogleArtifactRegistry|%{linkStart}Install the Google Cloud CLI%{linkEnd}.')
          "
        >
          <template #link="{ content }">
            <gl-link href="https://cloud.google.com/sdk/docs/install" target="_blank">
              {{ content }}
              <gl-icon name="external-link" :aria-label="__('(external link)')" />
            </gl-link>
          </template>
        </gl-sprintf>
      </li>
      <li>
        <gl-sprintf
          :message="
            s__(
              'GoogleArtifactRegistry|Ensure you have the %{linkStart}permissions%{linkEnd} to manage access to your Google Cloud project.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link
              href="https://cloud.google.com/iam/docs/granting-changing-revoking-access#required-permissions"
              target="_blank"
            >
              {{ content }}
              <gl-icon name="external-link" :aria-label="__('(external link)')" />
            </gl-link>
          </template>
        </gl-sprintf>
      </li>
      <li>
        <span>
          {{
            s__(
              'GoogleArtifactRegistry|Run the following command to grant roles in your Google Cloud project. You might be prompted to sign into Google.',
            )
          }}
        </span>
        <ul v-if="!hasId" class="gl-pl-5">
          <li>
            <gl-sprintf
              :message="
                s__(
                  'GoogleArtifactRegistry|Replace %{codeStart}your_google_cloud_project_id%{codeEnd} with your Google Cloud project ID.',
                )
              "
              ><template #code="{ content }">
                <code>&lt;{{ content }}&gt;</code>
              </template>
            </gl-sprintf>
          </li>
        </ul>
        <div class="gl-relative gl-mt-2">
          <clipboard-button
            :title="s__('GoogleArtifactRegistry|Copy command')"
            :text="instructions"
            class="gl-absolute gl-top-3 gl-right-3 gl-z-1"
          />
          <code-block-highlighted
            class="gl-border gl-p-4"
            language="powershell"
            :code="instructions"
            tabindex="0"
            role="group"
            :aria-label="s__('GoogleArtifactRegistry|Instructions')"
          />
        </div>
      </li>
      <li>
        <gl-sprintf
          :message="
            s__(
              'GoogleArtifactRegistry|After the roles have been granted, select %{strongStart}Save changes%{strongEnd} to continue.',
            )
          "
          ><template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>
    </ol>
  </div>
</template>
