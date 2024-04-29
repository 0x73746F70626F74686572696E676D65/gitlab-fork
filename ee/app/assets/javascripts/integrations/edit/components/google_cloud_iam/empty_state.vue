<script>
import { GlButton, GlEmptyState, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import EmptyAdminAppsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-admin-apps-md.svg';
import InviteMembersTrigger from '~/invite_members/components/invite_members_trigger.vue';
import { STATE_GUIDED, STATE_MANUAL } from './constants';

export default {
  components: {
    GlButton,
    GlIcon,
    GlEmptyState,
    GlLink,
    InviteMembersTrigger,
    GlSprintf,
  },
  methods: {
    show(type) {
      this.$emit('show', type);
    },
  },
  EmptyAdminAppsSvg,
  STATE_GUIDED,
  STATE_MANUAL,
};
</script>

<template>
  <gl-empty-state
    :svg-path="$options.EmptyAdminAppsSvg"
    :title="s__('GoogleCloud|Connect to Google Cloud')"
  >
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'GoogleCloud|Connect to Google Cloud with workload identity federation. Select %{strongStart}Guided setup%{strongEnd} if you can manage workload identity federation in Google Cloud. %{linkStart}What are the required permissions?%{linkEnd}',
          )
        "
      >
        <template #strong="{ content }">
          <strong>{{ content }}</strong>
        </template>
        <template #link="{ content }">
          <gl-link
            href="https://cloud.google.com/iam/docs/manage-workload-identity-pools-providers#required-roles"
            target="_blank"
          >
            {{ content }}
            <gl-icon name="external-link" :aria-label="__('(external link)')" />
          </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #actions>
      <div class="gl-display-flex gl-gap-3">
        <gl-button variant="confirm" @click="show($options.STATE_GUIDED)">{{
          s__('GoogleCloud|Guided setup')
        }}</gl-button>
        <gl-button data-testid="manual-setup-button" @click="show($options.STATE_MANUAL)">{{
          s__('GoogleCloud|Manual setup')
        }}</gl-button>
        <invite-members-trigger
          :display-text="s__('GoogleCloud|Invite member to set up')"
          trigger-source="google_cloud_artifact_registry_setup"
        />
      </div>
    </template>
  </gl-empty-state>
</template>
