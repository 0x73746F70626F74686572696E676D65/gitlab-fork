<script>
import { GlButton } from '@gitlab/ui';

export default {
  components: {
    GlButton,
  },
  inject: {
    manageMemberRolesPath: {
      default: null,
    },
  },
};
</script>

<template>
  <div v-if="manageMemberRolesPath" class="gl-border-t gl-border-gray-200 gl-p-2">
    <gl-button
      :href="manageMemberRolesPath"
      category="tertiary"
      class="gl-w-full gl-justify-content-start!"
    >
      {{ s__('MemberRole|Manage roles') }}
    </gl-button>
  </div>
</template>
