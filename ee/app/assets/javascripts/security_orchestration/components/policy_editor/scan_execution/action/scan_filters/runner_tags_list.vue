<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getBaseURL } from '~/lib/utils/url_utility';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import RunnerTagsDropdown from 'ee/vue_shared/components/runner_tags_dropdown/runner_tags_dropdown.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { isGroup } from 'ee/security_orchestration/components/utils';
import {
  TAGS_MODE_SELECTED_ITEMS,
  ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY,
  ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY,
} from '../../constants';

export default {
  TAGS_MODES: TAGS_MODE_SELECTED_ITEMS,
  name: 'RunnerTagsList',
  i18n: {
    resetButtonLabel: s__('SecurityOrchestration|Clear all'),
    runnersDisabledStatePopoverTitle: s__('SecurityOrchestration|No tags available'),
    runnersDisabledStatePopoverContent: s__(
      'SecurityOrchestration|Scan will automatically choose a runner to run on because there are no tags exist on runners. You can %{linkStart}create a new tag in settings%{linkEnd}.',
    ),
  },
  components: {
    GlCollapsibleListbox,
    PolicyPopover,
    RunnerTagsDropdown,
  },
  props: {
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_TYPES.PROJECT,
    },
    namespacePath: {
      type: String,
      required: false,
      default: '',
    },
    selectedTags: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    const selectedTagsMode = this.selectedTags.length
      ? ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY
      : ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY;

    return {
      selectedTagsMode,
      areRunnersTagged: true,
    };
  },
  computed: {
    isSpecificTagMode() {
      return this.selectedTagsMode === ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY;
    },
    runnersTagLink() {
      if (isGroup(this.namespaceType)) {
        return `${getBaseURL()}/groups/${this.namespacePath}/-/runners`;
      }

      return `${getBaseURL()}/${this.namespacePath}/-/runners`;
    },
  },
  methods: {
    setSelection(tags) {
      this.$emit('input', tags);
    },
    setSelectedTagsMode(key) {
      this.selectedTagsMode = TAGS_MODE_SELECTED_ITEMS.find(({ value }) => value === key).value;

      if (key === ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY) {
        this.setSelection([]);
      }
    },
    setTags(tags) {
      this.areRunnersTagged = Boolean(tags.length);
      if (tags.length === 0) {
        this.setSelectedTagsMode(ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY);
      }
    },
  },
};
</script>

<template>
  <div>
    <policy-popover
      class="gl-display-inline-block"
      :content="$options.i18n.runnersDisabledStatePopoverContent"
      :href="runnersTagLink"
      :title="$options.i18n.runnersDisabledStatePopoverTitle"
      :show-popover="!areRunnersTagged"
      target="runner-tags-switcher-id"
    >
      <template #trigger>
        <gl-collapsible-listbox
          id="runner-tags-switcher-id"
          class="gl-mr-2 gl-mb-3 gl-sm-mb-0"
          :disabled="!areRunnersTagged"
          :items="$options.TAGS_MODES"
          :selected="selectedTagsMode"
          @select="setSelectedTagsMode"
        />
      </template>
    </policy-popover>

    <runner-tags-dropdown
      v-if="isSpecificTagMode"
      toggle-class="gl-max-w-62"
      :empty-tags-list-placeholder="$options.i18n.noRunnerTagsText"
      :namespace-path="namespacePath"
      :namespace-type="namespaceType"
      :value="selectedTags"
      @input="setSelection"
      @tags-loaded="setTags"
      @error="$emit('error')"
    />
  </div>
</template>
