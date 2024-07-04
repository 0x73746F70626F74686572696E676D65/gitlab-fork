<script>
import { GlButton, GlButtonGroup, GlLoadingIcon, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { safeDump } from 'js-yaml';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import AnalyticsDashboardPanel from '../analytics_dashboard_panel.vue';

import {
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  PANEL_VISUALIZATION_HEIGHT,
} from '../../constants';
import AiCubeQueryFeedback from './ai_cube_query_feedback.vue';

export default {
  name: 'AnalyticsVisualizationPreview',
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  components: {
    AiCubeQueryFeedback,
    GlButton,
    GlButtonGroup,
    GlLoadingIcon,
    GlIcon,
    AnalyticsDashboardPanel,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedVisualizationType: {
      type: String,
      required: true,
    },
    displayType: {
      type: String,
      required: true,
    },
    isQueryPresent: {
      type: Boolean,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    resultVisualization: {
      type: Object,
      required: false,
      default: null,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    aiPromptCorrelationId: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    previewYamlConfiguration() {
      return this.resultVisualization && safeDump(this.resultVisualization);
    },
  },
  methods: {
    handleVisualizationError(visualizationTitle, error) {
      createAlert({
        message: sprintf(
          s__('Analytics|An error occurred while loading the %{visualizationTitle} visualization.'),
          { visualizationTitle },
        ),
        error,
        captureError: true,
      });
    },
  },
  PANEL_VISUALIZATION_HEIGHT,
};
</script>

<template>
  <div>
    <div v-if="!isQueryPresent || loading">
      <div class="col-12 gl-mt-4">
        <div class="text-content text-center gl-text-gray-400">
          <h3 v-if="!isQueryPresent" data-testid="measurement-hl" class="gl-text-gray-400">
            {{ s__('Analytics|Start by choosing a metric') }}
          </h3>
          <gl-loading-icon
            v-else-if="loading"
            size="lg"
            class="gl-mt-6"
            data-testid="loading-icon"
          />
        </div>
      </div>
    </div>
    <div v-if="resultVisualization && isQueryPresent">
      <div
        class="gl-m-5 gl-gap-5 gl-display-flex gl-flex-wrap-reverse gl-justify-content-space-between gl-align-items-center"
      >
        <div class="gl-display-flex gl-gap-3">
          <gl-button-group>
            <gl-button
              v-for="buttonDisplayType in $options.PANEL_DISPLAY_TYPE_ITEMS"
              :key="buttonDisplayType.type"
              :selected="displayType === buttonDisplayType.type"
              :icon="buttonDisplayType.icon"
              :data-testid="`select-${buttonDisplayType.type}-button`"
              @click="$emit('selectedDisplayType', buttonDisplayType.type)"
              >{{ buttonDisplayType.title }}</gl-button
            >
          </gl-button-group>
          <gl-icon
            v-gl-tooltip
            :title="
              s__(
                'Analytics|The visualization preview displays only the last 7 days. Dashboard visualizations can display the entire date range.',
              )
            "
            name="information-o"
            class="gl-align-self-end gl-mb-3 gl-text-gray-500 gl-min-w-5"
          />
        </div>
        <ai-cube-query-feedback
          v-if="aiPromptCorrelationId"
          :correlation-id="aiPromptCorrelationId"
          class="gl-ml-auto gl-h-full"
        />
      </div>
      <div class="border-light gl-border gl-rounded-base gl-m-5 gl-shadow-sm gl-overflow-auto">
        <div v-if="displayType === $options.PANEL_DISPLAY_TYPES.VISUALIZATION">
          <analytics-dashboard-panel
            v-if="selectedVisualizationType"
            :title="title"
            :visualization="resultVisualization"
            :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
            data-testid="preview-visualization"
            class="gl-border-none gl-shadow-none"
            @error="(error) => handleVisualizationError('TITLE', error)"
          />
          <div
            v-else
            class="col-12 gl-bg-white gl-overflow-y-auto"
            :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
          >
            <div class="text-content text-center gl-text-gray-400">
              <h3 class="gl-text-gray-400">
                {{ s__('Analytics|Select a visualization type') }}
              </h3>
            </div>
          </div>
        </div>

        <div v-if="displayType === $options.PANEL_DISPLAY_TYPES.CODE" class="gl-bg-white gl-p-4">
          <pre
            class="code highlight gl-display-flex gl-bg-transparent gl-border-none"
            data-testid="preview-code"
          ><code>{{ previewYamlConfiguration }}</code></pre>
        </div>
      </div>
    </div>
  </div>
</template>
