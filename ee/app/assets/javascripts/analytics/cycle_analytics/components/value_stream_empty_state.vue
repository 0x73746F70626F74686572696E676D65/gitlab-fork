<script>
import { GlButton, GlEmptyState, GlLoadingIcon, GlModalDirective } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import Tracking from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  EMPTY_STATE_TITLE,
  EMPTY_STATE_DESCRIPTION,
  EMPTY_STATE_ACTION_TEXT,
  EMPTY_STATE_SECONDARY_TEXT,
  EMPTY_STATE_FILTER_ERROR_TITLE,
  EMPTY_STATE_FILTER_ERROR_DESCRIPTION,
} from '../constants';
import ValueStreamForm from './value_stream_form.vue';

export default {
  name: 'ValueStreamEmptyState',
  components: {
    GlButton,
    GlEmptyState,
    GlLoadingIcon,
    ValueStreamForm,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [Tracking.mixin(), glFeatureFlagsMixin()],
  inject: ['newValueStreamPath'],
  props: {
    isLoading: {
      type: Boolean,
      required: true,
      default: false,
    },
    hasDateRangeError: {
      type: Boolean,
      required: true,
      default: false,
    },
    emptyStateSvgPath: {
      type: String,
      required: true,
    },
    canEdit: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  computed: {
    title() {
      return this.hasDateRangeError
        ? this.$options.i18n.EMPTY_STATE_FILTER_ERROR_TITLE
        : this.$options.i18n.EMPTY_STATE_TITLE;
    },
    description() {
      return this.hasDateRangeError
        ? this.$options.i18n.EMPTY_STATE_FILTER_ERROR_DESCRIPTION
        : this.$options.i18n.EMPTY_STATE_DESCRIPTION;
    },
    isVSAStandaloneSettingsPageEnabled() {
      return this.glFeatures?.vsaStandaloneSettingsPage;
    },
    createValueStreamHref() {
      return this.isVSAStandaloneSettingsPageEnabled ? this.newValueStreamPath : null;
    },
    valueStreamFormModalId() {
      return !this.isVSAStandaloneSettingsPageEnabled && 'value-stream-form-modal';
    },
  },
  i18n: {
    EMPTY_STATE_TITLE,
    EMPTY_STATE_DESCRIPTION,
    EMPTY_STATE_ACTION_TEXT,
    EMPTY_STATE_SECONDARY_TEXT,
    EMPTY_STATE_FILTER_ERROR_TITLE,
    EMPTY_STATE_FILTER_ERROR_DESCRIPTION,
  },
  docsPath: helpPagePath('user/group/value_stream_analytics/index', {
    anchor: 'custom-value-streams',
  }),
};
</script>
<template>
  <div>
    <div v-if="isLoading" class="gl-p-7 gl-text-center">
      <gl-loading-icon size="lg" />
    </div>
    <gl-empty-state
      v-else
      :svg-path="emptyStateSvgPath"
      :title="title"
      :description="description"
      data-testid="vsa-empty-state"
    >
      <template v-if="!hasDateRangeError && canEdit" #actions>
        <gl-button
          v-gl-modal-directive="valueStreamFormModalId"
          :href="createValueStreamHref"
          class="gl-mx-2 gl-mb-3"
          variant="confirm"
          data-testid="create-value-stream-button"
          data-track-action="click_button"
          data-track-label="empty_state_create_value_stream_form_open"
          >{{ $options.i18n.EMPTY_STATE_ACTION_TEXT }}</gl-button
        >
        <gl-button class="gl-mx-2 gl-mb-3" data-testid="learn-more-link" :href="$options.docsPath"
          >{{ $options.i18n.EMPTY_STATE_SECONDARY_TEXT }}
        </gl-button>
      </template>
    </gl-empty-state>
    <value-stream-form />
  </div>
</template>
