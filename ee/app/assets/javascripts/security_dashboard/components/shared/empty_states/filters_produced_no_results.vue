<script>
import { GlEmptyState } from '@gitlab/ui';

export default {
  components: {
    GlEmptyState,
  },
  inject: ['noVulnerabilitiesSvgPath'],
};
</script>

<template>
  <gl-empty-state
    :title="s__('SecurityReports|Sorry, your filter produced no results')"
    :svg-path="noVulnerabilitiesSvgPath"
    :svg-height="150"
    :description="s__(`SecurityReports|To widen your search, change or remove filters above`)"
  />
</template>
