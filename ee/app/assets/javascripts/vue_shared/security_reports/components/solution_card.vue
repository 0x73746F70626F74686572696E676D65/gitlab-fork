<script>
import SafeHtml from '~/vue_shared/directives/safe_html';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { s__ } from '~/locale';

export default {
  directives: {
    SafeHtml,
  },
  props: {
    solutionText: {
      type: String,
      required: true,
    },
    canDownloadPatch: {
      type: Boolean,
      required: true,
    },
  },
  i18n: {
    createMergeRequestMsg: s__(
      'ciReport|Create a merge request to implement this solution, or download and apply the patch manually.',
    ),
  },
  mounted() {
    renderGFM(this.$refs.markdownContent);
  },
};
</script>
<template>
  <div>
    <h3>{{ s__('ciReport|Solution') }}</h3>
    <p ref="markdownContent" v-safe-html="solutionText" data-testid="solution-text"></p>
    <p v-if="canDownloadPatch" class="gl-italic" data-testid="create-mr-message">
      {{ $options.i18n.createMergeRequestMsg }}
    </p>
  </div>
</template>
