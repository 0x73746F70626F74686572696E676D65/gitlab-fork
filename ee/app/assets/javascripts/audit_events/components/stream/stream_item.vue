<script>
import {
  GlAlert,
  GlBadge,
  GlLink,
  GlPopover,
  GlSprintf,
  GlCollapse,
  GlIcon,
  GlButton,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import {
  STREAM_ITEMS_I18N,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
  UPDATE_STREAM_MESSAGE,
} from '../../constants';
import StreamDestinationEditor from './stream_destination_editor.vue';
import StreamGcpLoggingDestinationEditor from './stream_gcp_logging_destination_editor.vue';
import StreamAmazonS3DestinationEditor from './stream_amazon_s3_destination_editor.vue';

export default {
  components: {
    GlAlert,
    GlBadge,
    GlLink,
    GlPopover,
    GlSprintf,
    GlCollapse,
    GlButton,
    GlIcon,
    StreamDestinationEditor,
    StreamGcpLoggingDestinationEditor,
    StreamAmazonS3DestinationEditor,
  },
  directives: {
    GlTooltip,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isEditing: false,
      successMessage: null,
    };
  },
  computed: {
    isItemFiltered() {
      return Boolean(this.item?.eventTypeFilters?.length) || Boolean(this.item?.namespaceFilter);
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationTitle() {
      return this.item.name;
    },
  },
  methods: {
    toggleEditMode() {
      this.isEditing = !this.isEditing;

      if (!this.isEditing) {
        this.clearSuccessMessage();
      }
    },
    onUpdated() {
      this.successMessage = UPDATE_STREAM_MESSAGE;
      this.$emit('updated');
    },
    onDelete($event) {
      this.$emit('deleted', $event);
    },
    onEditorError() {
      this.clearSuccessMessage();
      this.$emit('error');
    },
    clearSuccessMessage() {
      this.successMessage = null;
    },
  },
  i18n: { ...STREAM_ITEMS_I18N },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <li class="list-item py-0">
    <div class="gl-display-flex gl-align-items-center gl-justify-content-space-between gl-py-6">
      <gl-button
        variant="link"
        class="gl-text-body! gl-font-bold gl-min-w-0"
        :aria-expanded="isEditing"
        data-testid="toggle-btn"
        @click="toggleEditMode"
      >
        <gl-icon
          name="chevron-right"
          class="gl-transition-all"
          :class="{ 'gl-rotate-90': isEditing }"
        /><span class="gl-font-lg gl-ml-2">{{ destinationTitle }}</span>
      </gl-button>

      <template v-if="isItemFiltered">
        <gl-popover :target="item.id" data-testid="filter-popover">
          <gl-sprintf :message="$options.i18n.FILTER_TOOLTIP_LABEL">
            <template #link="{ content }">
              <gl-link :href="$options.i18n.FILTER_TOOLTIP_LINK" target="_blank">
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-popover>
        <gl-badge
          :id="item.id"
          icon="filter"
          variant="neutral"
          data-testid="filter-badge"
          class="gl-ml-3 gl-mr-auto"
        >
          {{ $options.i18n.FILTER_BADGE_LABEL }}
        </gl-badge>
      </template>
    </div>
    <gl-collapse :visible="isEditing">
      <gl-alert
        v-if="successMessage"
        :dismissible="true"
        class="gl-ml-6 gl-mb-6"
        variant="success"
        @dismiss="clearSuccessMessage"
      >
        {{ successMessage }}
      </gl-alert>
      <stream-destination-editor
        v-if="type == $options.DESTINATION_TYPE_HTTP"
        :item="item"
        class="gl-pr-0 gl-pl-6 gl-pb-5"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
      <stream-gcp-logging-destination-editor
        v-else-if="type == $options.DESTINATION_TYPE_GCP_LOGGING"
        :item="item"
        class="gl-pr-0 gl-pl-6 gl-pb-5"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
      <stream-amazon-s3-destination-editor
        v-else-if="type == $options.DESTINATION_TYPE_AMAZON_S3"
        :item="item"
        class="gl-pr-0 gl-pl-6 gl-pb-5"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
    </gl-collapse>
  </li>
</template>
