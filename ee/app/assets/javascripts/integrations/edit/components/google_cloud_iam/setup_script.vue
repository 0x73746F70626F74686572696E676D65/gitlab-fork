<script>
import { GlAlert, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';

export default {
  components: {
    GlAlert,
    GlIcon,
    GlLink,
    GlSprintf,
    ClipboardButton,
    CodeBlockHighlighted,
  },
  props: {
    wlifIssuer: {
      type: String,
      required: true,
    },
    googleProjectId: {
      type: String,
      required: true,
    },
    identityPoolId: {
      type: String,
      required: true,
    },
    identityProviderId: {
      type: String,
      required: true,
    },
    jwtClaims: {
      type: String,
      required: true,
    },
    suggestedDisplayName: {
      type: String,
      required: true,
    },
  },
  computed: {
    gCloudCommands() {
      return `# Create workload identity pool
gcloud iam workload-identity-pools create "${this.identityPoolId}" \\
  --project="${this.googleProjectId}" \\
  --location="global" \\
  --display-name="${this.suggestedDisplayName}"

# Create OIDC provider with the required configuration in the workload identity pool
gcloud iam workload-identity-pools providers create-oidc "${this.identityProviderId}" \\
  --location="global" \\
  --project="${this.googleProjectId}" \\
  --workload-identity-pool="${this.identityPoolId}" \\
  --issuer-uri="${this.wlifIssuer}" \\
  --display-name="${this.suggestedDisplayName}" \\
  --attribute-mapping="${this.jwtClaims}"
`;
    },
  },
  helpURL: helpPagePath('integration/google_cloud_iam', {
    anchor: 'with-the-google-cloud-cli',
  }),
};
</script>

<template>
  <div>
    <h3>{{ s__('GoogleCloud|2. Set up workload identity federation') }}</h3>

    <gl-alert :dismissible="false">
      <gl-sprintf
        :message="
          s__(
            'GoogleCloud|If workload identity federation is already set up with the %{linkStart}required configuration%{linkEnd}, skip this step and select %{strongStart}Save changes%{strongEnd} to continue.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link target="_blank" :href="$options.helpURL">
            {{ content }}
            <gl-icon name="external-link" :aria-label="__('(external link)')" />
          </gl-link>
        </template>
        <template #strong="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>

    <p class="gl-mt-4">
      {{
        s__(
          'GoogleCloud|To create the workload identity pool and provider in your Google Cloud project, with the required configuration:',
        )
      }}
    </p>

    <ol>
      <li>
        <gl-sprintf
          :message="s__('GoogleCloud|%{linkStart}Install the Google Cloud CLI%{linkEnd}.')"
        >
          <template #link="{ content }">
            <gl-link
              target="_blank"
              href="https://cloud.google.com/sdk/docs/install#installation_instructions"
            >
              {{ content }}
              <gl-icon name="external-link" :aria-label="__('(external link)')" />
            </gl-link>
          </template>
        </gl-sprintf>
      </li>
      <li>
        <p>
          {{
            s__(
              'GoogleCloud|Run the following commands. You might be prompted to sign in to Google.',
            )
          }}
        </p>

        <div class="position-relative">
          <code-block-highlighted
            class="gl-border gl-p-4"
            language="powershell"
            :code="gCloudCommands"
          />
          <clipboard-button
            :text="gCloudCommands"
            :title="__('Copy command')"
            category="tertiary"
            class="gl-hidden md:gl-flex position-absolute position-top-0 position-right-0 gl-m-3"
          />
        </div>
      </li>
      <li>
        <gl-sprintf
          :message="
            s__(
              'GoogleCloud|After the setup is complete, select %{strongStart}Save changes%{strongEnd} to continue.',
            )
          "
        >
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>
    </ol>
  </div>
</template>
