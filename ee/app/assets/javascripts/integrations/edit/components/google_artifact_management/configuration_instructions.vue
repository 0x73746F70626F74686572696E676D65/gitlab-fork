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
    personalAccessTokensPath() {
      return this.propsSource.personalAccessTokensPath;
    },
    googleCloudProjectId() {
      return this.id || '<your_google_cloud_project_id>';
    },
    instructions() {
      return `curl --request GET \\
--header "PRIVATE-TOKEN: <your_access_token>" \\
--data 'google_cloud_artifact_registry_project_id=${this.googleCloudProjectId}' \\
--data 'enable_google_cloud_artifact_registry=true' \\
--url "https://gitlab.com/api/v4/projects/${this.projectId}/google_cloud/setup/integrations.sh" \\
| bash`;
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
    <ul>
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
    </ul>
    <p>
      {{
        s__(
          'GoogleArtifactRegistry|Run the following command to grant roles in your Google Cloud project. You might be prompted to sign into Google.',
        )
      }}
    </p>
    <ul>
      <li>
        <gl-sprintf
          :message="
            s__(
              'GoogleArtifactRegistry|Replace %{codeStart}your_access_token%{codeEnd} with a new %{linkStart}personal access token%{linkEnd} with the %{strongStart}read_api%{strongEnd} scope. This token gets information from your Google Cloud IAM integration in GitLab.',
            )
          "
          ><template #code="{ content }">
            <code>&lt;{{ content }}&gt;</code>
          </template>
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
          <template #link="{ content }">
            <gl-link :href="personalAccessTokensPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </li>
      <li v-if="!hasId">
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
    <div class="gl-relative">
      <clipboard-button
        :title="s__('GoogleArtifactRegistry|Copy command')"
        :text="instructions"
        class="gl-absolute gl-top-3 gl-right-3 gl-z-1"
      />
      <code-block-highlighted class="gl-border gl-p-4" language="powershell" :code="instructions" />
    </div>
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
  </div>
</template>
