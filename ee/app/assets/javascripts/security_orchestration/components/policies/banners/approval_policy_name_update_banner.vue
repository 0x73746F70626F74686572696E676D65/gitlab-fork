<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';
import { PROMO_URL } from '~/lib/utils/url_utility';

export default {
  BANNER_STORAGE_KEY: 'security_policies_scan_result_name_change',
  i18n: {
    migrationTitle: s__('SecurityOrchestration|Updated policy name'),
    migrationDescription: {
      text: s__(
        'SecurityOrchestration|The %{oldNameStart}Scan result policy%{oldNameEnd} is now called the %{newNameStart}Merge request approval policy%{newNameEnd} to better align with its purpose. For more details, see %{linkStart}the release notes%{linkEnd}.',
      ),
      href: `${PROMO_URL}/releases/2024/03/21/gitlab-16-10-released/#scan-result-policies-are-now-merge-request-approval-policies`,
    },
  },
  name: 'ApprovalPolicyNameUpdateBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    LocalStorageSync,
  },
  data() {
    return {
      alertDismissed: false,
    };
  },
  methods: {
    dismissAlert() {
      this.alertDismissed = true;
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <gl-alert
      v-if="!alertDismissed"
      class="gl-mb-6"
      :dismissible="true"
      :title="$options.i18n.migrationTitle"
      @dismiss="dismissAlert"
    >
      <gl-sprintf :message="$options.i18n.migrationDescription.text">
        <template #oldName="{ content }">
          <b>{{ content }}</b>
        </template>
        <template #newName="{ content }">
          <b>{{ content }}</b>
        </template>
        <template #link="{ content }">
          <gl-link :href="$options.i18n.migrationDescription.href" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </local-storage-sync>
</template>
