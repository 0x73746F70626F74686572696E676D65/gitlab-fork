<script>
import { GlSkeletonLoader, GlIcon, GlPopover, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { fetchPolicies } from '~/lib/graphql';
import getProjectContainerScanning from '../../graphql/queries/get_project_container_scanning.query.graphql';

export default {
  components: {
    GlIcon,
    GlSkeletonLoader,
    GlPopover,
    GlLink,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['config'],
  apollo: {
    containerScanningData: {
      query: getProjectContainerScanning,
      variables() {
        return {
          fullPath: this.config.projectPath,
          securityConfigurationPath: this.config.securityConfigurationPath,
        };
      },
      // We need this for handling loading state when using frontend cache
      // See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/106004#note_1217325202 for details
      fetchPolicy: fetchPolicies.CACHE_ONLY,
      notifyOnNetworkStatusChange: true,
      update(data) {
        return data.project.containerScanningForRegistry ?? { isEnabled: false, isVisible: false };
      },
    },
  },
  computed: {
    isMetaVisible() {
      return this.containerScanningData?.isVisible;
    },
    metaText() {
      return this.containerScanningData?.isEnabled
        ? s__('ContainerRegistry|Container Scanning for Registry: On')
        : s__('ContainerRegistry|Container Scanning for Registry: Off');
    },
    isEmpty() {
      return !this.glFeatures.containerScanningForRegistryFlag;
    },
  },
};
</script>

<template>
  <div v-if="!isEmpty" class="gl-inline-flex gl-items-center">
    <gl-skeleton-loader v-if="$apollo.queries.containerScanningData.loading" :lines="1" />
    <template v-if="isMetaVisible">
      <div id="popover-target" data-testid="container-scanning-metadata">
        <gl-icon name="shield" class="gl-text-gray-500 gl-min-w-5 gl-mr-3" /><span
          class="gl-font-bold gl-inline-flex"
          >{{ metaText }}</span
        >
      </div>
      <gl-popover
        data-testid="container-scanning-metadata-popover"
        target="popover-target"
        triggers="hover focus click"
        placement="bottom"
      >
        {{
          s__(
            'ContainerRegistry|Continuous container scanning runs in the registry when any image or database is updated.',
          )
        }}
        <br />
        <br />
        <gl-link :href="config.containerScanningForRegistryDocsPath" class="gl-font-bold">
          {{ __('What is continuous container scanning?') }}
        </gl-link>
      </gl-popover>
    </template>
  </div>
</template>
