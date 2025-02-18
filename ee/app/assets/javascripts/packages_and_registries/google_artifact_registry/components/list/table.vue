<script>
import {
  GlAlert,
  GlBadge,
  GlKeysetPagination,
  GlLoadingIcon,
  GlTable,
  GlTruncate,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

export default {
  name: 'ListTable',
  components: {
    ClipboardButton,
    GlAlert,
    GlBadge,
    GlKeysetPagination,
    GlLoadingIcon,
    GlTable,
    GlTruncate,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    sort: {
      type: Object,
      required: true,
    },
  },
  computed: {
    images() {
      return this.data?.nodes ?? [];
    },
    pageInfo() {
      return this.data?.pageInfo ?? {};
    },
  },
  methods: {
    getShortDigest(digest) {
      // remove sha256: from the string, and show only the first 12 char
      return digest.substring(7, 19);
    },
    getImageNameAndShortDigest(item) {
      return `${item.image}@${this.getShortDigest(item.digest)}`;
    },
    getTagsToShow(item) {
      const { tags = [] } = item;
      return tags.slice(0, 2);
    },
    getHiddenTagCountWithTooltip(item) {
      const { tags = [] } = item;
      const extraTags = tags.slice(2);
      if (extraTags.length) {
        return {
          label: `+${extraTags.length}`,
          tooltipText: sprintf(
            n__(
              'GoogleArtifactRegistry|%d more tag',
              'GoogleArtifactRegistry|%d more tags',
              extraTags.length,
            ),
          ),
        };
      }
      return extraTags.length;
    },
  },
  filesTableHeaderFields: [
    {
      key: 'image',
      label: s__('GoogleArtifactRegistry|Name'),
      thClass: 'gl-w-2/5',
      tdClass: 'gl-pt-3!',
    },
    {
      key: 'tags',
      label: s__('GoogleArtifactRegistry|Tags'),
      tdClass: 'gl-pt-4!',
    },
    {
      key: 'uploadTime',
      label: s__('GoogleArtifactRegistry|Created'),
    },
    {
      key: 'updateTime',
      label: s__('GoogleArtifactRegistry|Updated'),
      sortable: true,
    },
  ],
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" :dismissible="false" class="gl-mb-3">
      {{ errorMessage }}
    </gl-alert>
    <gl-table
      :busy="isLoading"
      :fields="$options.filesTableHeaderFields"
      :items="images"
      show-empty
      stacked="md"
      :sort-by="sort.sortBy"
      :sort-desc="sort.sortDesc"
      no-local-sorting
      table-class="gl-table-layout-fixed"
      @sort-changed="$emit('sort-changed', $event)"
    >
      <template #table-busy>
        <gl-loading-icon size="sm" class="gl-my-5" />
      </template>
      <template #cell(image)="{ item }">
        <div
          class="gl-display-flex gl-align-items-center gl-justify-content-end gl-md-justify-content-start"
        >
          <router-link class="gl-text-body gl-min-w-0" :to="item.name">
            <gl-truncate
              class="gl-font-bold"
              position="middle"
              :text="getImageNameAndShortDigest(item)"
              :with-tooltip="true"
            />
          </router-link>
          <clipboard-button
            :title="s__('GoogleArtifactRegistry|Copy image path')"
            :text="item.uri"
            category="tertiary"
          />
        </div>
      </template>
      <template #cell(tags)="{ item }">
        <div
          class="gl-display-flex gl-flex-wrap gl-gap-2 gl-justify-content-end gl-md-justify-content-start"
        >
          <gl-badge v-for="tag in getTagsToShow(item)" :key="tag" class="gl-max-w-12">
            <gl-truncate class="gl-max-w-80p" :text="tag" :with-tooltip="true" /> </gl-badge
          ><gl-badge
            v-if="getHiddenTagCountWithTooltip(item)"
            v-gl-tooltip
            data-testid="more-tags-badge"
            :title="getHiddenTagCountWithTooltip(item).tooltipText"
            aria-hidden="true"
            ><span>{{ getHiddenTagCountWithTooltip(item).label }}</span>
          </gl-badge>
          <span
            v-if="getHiddenTagCountWithTooltip(item)"
            class="gl-sr-only"
            data-testid="more-tags-badge-sr-text"
            >{{ getHiddenTagCountWithTooltip(item).tooltipText }}</span
          >
        </div>
      </template>
      <template #cell(uploadTime)="{ item }">
        <time-ago-tooltip :time="item.uploadTime" />
      </template>
      <template #cell(updateTime)="{ item }">
        <time-ago-tooltip :time="item.updateTime" />
      </template>
    </gl-table>
    <div class="gl-display-flex gl-justify-content-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </div>
  </div>
</template>
