<script>
import { QueryBuilder } from '@cubejs-client/vue';
import { GlButton, GlFormGroup, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import { isEqual } from 'lodash';

import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { slugify } from '~/lib/utils/text_utility';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

import { createCubeApi } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import { getVisualizationOptions } from 'ee/analytics/analytics_dashboards/utils/visualization_designer_options';
import { saveProductAnalyticsVisualization } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import { NEW_DASHBOARD_SLUG } from 'ee/vue_shared/components/customizable_dashboard/constants';

import {
  FILE_ALREADY_EXISTS_SERVER_RESPONSE,
  PANEL_DISPLAY_TYPES,
  EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER,
  EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
  DEFAULT_VISUALIZATION_QUERY_STATE,
  DEFAULT_VISUALIZATION_TITLE,
  DEFAULT_SELECTED_VISUALIZATION_TYPE,
} from '../constants';
import MeasureSelector from './visualization_designer/selectors/product_analytics/measure_selector.vue';
import DimensionSelector from './visualization_designer/selectors/product_analytics/dimension_selector.vue';
import VisualizationPreview from './visualization_designer/analytics_visualization_preview.vue';
import VisualizationTypeSelector from './visualization_designer/analytics_visualization_type_selector.vue';
import AiCubeQueryGenerator from './visualization_designer/ai_cube_query_generator.vue';
import VisualizationFilteredSearch from './visualization_designer/filters/visualization_filtered_search.vue';

export default {
  name: 'AnalyticsVisualizationDesigner',
  components: {
    AiCubeQueryGenerator,
    QueryBuilder,
    GlButton,
    GlFormInput,
    GlFormGroup,
    GlLink,
    GlSprintf,
    MeasureSelector,
    DimensionSelector,
    VisualizationFilteredSearch,
    VisualizationTypeSelector,
    VisualizationPreview,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  inject: {
    aiGenerateCubeQueryEnabled: {
      type: Boolean,
    },
    customDashboardsProject: {
      type: Object,
      default: null,
    },
  },
  async beforeRouteLeave(to, from, next) {
    const confirmed = await this.confirmDiscardIfChanged();
    if (!confirmed) return;

    next();
  },
  data() {
    return {
      cubeApi: createCubeApi(document.body.dataset.projectId),
      queryState: DEFAULT_VISUALIZATION_QUERY_STATE(),
      visualizationTitle: '',
      titleValidationError: null,
      typeValidationError: null,
      selectedDisplayType: PANEL_DISPLAY_TYPES.DATA,
      selectedVisualizationType: '',
      hasTimeDimension: false,
      isSaving: false,
      alert: null,
      aiPromptCorrelationId: null,
      aiPrompt: '',
    };
  },
  computed: {
    resultVisualization() {
      const newCubeQuery = this.$refs.builder.$children[0].resultSet.query();

      // Weird behaviour as the API says its malformed if we send it again
      delete newCubeQuery.order;
      delete newCubeQuery.rowLimit;
      delete newCubeQuery.queryType;

      return {
        version: 1,
        type: this.selectedVisualizationType,
        data: {
          type: 'cube_analytics',
          query: newCubeQuery,
        },
        options: this.panelOptions,
      };
    },
    panelOptions() {
      return getVisualizationOptions(
        this.selectedVisualizationType,
        this.hasTimeDimension,
        this.queryState.measureSubType,
      );
    },
    saveButtonText() {
      return this.$route?.params.dashboardid
        ? s__('Analytics|Save and add to Dashboard')
        : s__('Analytics|Save your visualization');
    },
    changesMade() {
      return (
        this.visualizationTitle !== DEFAULT_VISUALIZATION_TITLE ||
        this.selectedVisualizationType !== DEFAULT_SELECTED_VISUALIZATION_TYPE ||
        this.queryStateHasChanges
      );
    },
    queryStateHasChanges() {
      return !isEqual({ ...this.queryState }, DEFAULT_VISUALIZATION_QUERY_STATE());
    },
    showDimensionSelector() {
      return Boolean(this.queryState.query?.measures?.length);
    },
    filteringUiEnabled() {
      return this.glFeatures.analyticsVisualizationDesignerFiltering;
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();
    window.removeEventListener('beforeunload', this.onPageUnload);
  },
  mounted() {
    const wrappers = document.querySelectorAll('.container-fluid.container-limited');

    wrappers.forEach((el) => {
      el.classList.remove('container-limited');
    });

    this.trackEvent(EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER);

    window.addEventListener('beforeunload', this.onPageUnload);
  },
  methods: {
    onQueryStatusChange({ error }) {
      if (!error) {
        this.alert?.dismiss();
        return;
      }

      this.showAlert(s__('Analytics|An error occurred while loading data'), error, true);
    },
    onVizStateChange(state) {
      this.hasTimeDimension = Boolean(state.query.timeDimensions?.length);
      this.queryState.query = state.query;
    },
    onFilterChange(query) {
      this.queryState.query = { ...query };
    },
    measureUpdated(measureType, measureSubType) {
      this.queryState.measureType = measureType;
      this.queryState.measureSubType = measureSubType;
    },
    selectDisplayType(newType) {
      this.selectedDisplayType = newType;
    },
    selectVisualizationType(newType) {
      this.selectDisplayType(PANEL_DISPLAY_TYPES.VISUALIZATION);
      this.selectedVisualizationType = newType;
      this.validateType();
    },
    getRequiredFieldError(fieldValue) {
      return fieldValue.length > 0 ? '' : __('This field is required.');
    },
    validateType(isSubmitting) {
      // Don't validate if the type has not been submitted
      if (this.typeValidationError !== null || isSubmitting) {
        this.typeValidationError = this.getRequiredFieldError(this.selectedVisualizationType);
      }
    },
    validateTitle(submitting) {
      // Don't validate if the title has not been submitted
      if (this.titleValidationError !== null || submitting) {
        this.titleValidationError = this.getRequiredFieldError(this.visualizationTitle);
      }
    },
    getMetricsValidationError() {
      if (!this.queryState.query?.measures?.length) {
        return s__('Analytics|Select a measurement');
      }
      return null;
    },
    async saveVisualization() {
      let invalid = false;

      this.validateType(true);
      if (this.typeValidationError) {
        this.$refs.typeSelector.$el.querySelector('button').focus();
        invalid = true;
      }

      this.validateTitle(true);
      if (this.titleValidationError) {
        this.$refs.titleInput.$el.focus();
        invalid = true;
      }

      const validationError = this.getMetricsValidationError();
      if (validationError) {
        this.showAlert(validationError);
        invalid = true;
      }

      if (invalid) return;

      this.isSaving = true;

      try {
        const filename = slugify(this.visualizationTitle, '_');

        const saveResult = await saveProductAnalyticsVisualization(
          filename,
          this.resultVisualization,
          this.customDashboardsProject,
        );

        if (saveResult.status === HTTP_STATUS_CREATED) {
          this.alert?.dismiss();

          this.$toast.show(s__('Analytics|Visualization was saved successfully'));

          this.trackEvent(EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION);

          this.resetToInitialState();

          if (this.$route?.params.dashboard) {
            this.routeToDashboard(this.$route?.params.dashboard);
          }
        } else {
          this.showAlert(
            this.$options.i18n.saveError,
            new Error(
              `Received an unexpected HTTP status while saving visualization: ${saveResult.status}`,
            ),
            true,
          );
        }
      } catch (error) {
        const { message = '' } = error?.response?.data || {};

        if (message === FILE_ALREADY_EXISTS_SERVER_RESPONSE) {
          this.titleValidationError = s__(
            'Analytics|A visualization with that name already exists.',
          );
        } else {
          this.showAlert(`${this.$options.i18n.saveError} ${message}`.trimEnd(), error, true);
        }
      } finally {
        this.isSaving = false;
      }
    },
    routeToDashboard(dashboard) {
      if (dashboard === NEW_DASHBOARD_SLUG) {
        this.$router.push('/new');
      } else {
        this.$router.push({
          name: 'dashboard-detail',
          params: {
            slug: dashboard,
            editing: true,
          },
        });
      }
    },
    routeToDashboardList() {
      this.$router.push('/');
    },
    confirmDiscardIfChanged() {
      if (!this.changesMade) {
        return true;
      }

      return confirmAction(
        s__('Analytics|Are you sure you want to cancel creating this visualization?'),
        {
          primaryBtnText: __('Discard changes'),
          cancelBtnText: s__('Analytics|Continue creating'),
        },
      );
    },
    onPageUnload(event) {
      if (!this.changesMade) return undefined;

      event.preventDefault();
      // This returnValue is required on some browsers. This message is displayed on older versions.
      // https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event#compatibility_notes
      const returnValue = __('Are you sure you want to lose unsaved changes?');
      Object.assign(event, { returnValue });
      return returnValue;
    },
    showAlert(message, error = null, captureError = false) {
      this.alert = createAlert({
        message,
        error,
        captureError,
      });
    },
    onQueryGenerated(query, correlationId) {
      this.queryState.query = {
        ...query,
      };
      this.aiPromptCorrelationId = correlationId;
    },
    resetToInitialState() {
      this.queryState = DEFAULT_VISUALIZATION_QUERY_STATE();
      this.visualizationTitle = '';
      this.selectedVisualizationType = '';
      this.aiPromptCorrelationId = null;
      this.aiPrompt = '';
    },
  },
  i18n: {
    saveError: s__('Analytics|Error while saving visualization.'),
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards', {
    anchor: 'visualization-designer',
  }),
};
</script>

<template>
  <div>
    <header class="gl-my-6">
      <h2 class="gl-mt-0" data-testid="page-title">
        {{ s__('Analytics|Create your visualization') }}
      </h2>
      <p data-testid="page-description" class="gl-mb-0">
        {{
          s__(
            'Analytics|Use the visualization designer to create custom visualizations. After you save a visualization, you can add it to a dashboard.',
          )
        }}
        <gl-sprintf :message="__('%{linkStart} Learn more%{linkEnd}.')">
          <template #link="{ content }">
            <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </header>
    <section class="gl-display-flex gl-mb-6">
      <div class="gl-display-flex flex-fill gl-flex-direction-column">
        <gl-form-group
          :label="s__('Analytics|Visualization title')"
          label-for="title"
          class="gl-w-full gl-md-max-w-70p gl-lg-w-30p gl-min-w-20"
          data-testid="visualization-title-form-group"
          :invalid-feedback="titleValidationError"
          :state="!titleValidationError"
        >
          <gl-form-input
            id="title"
            ref="titleInput"
            v-model="visualizationTitle"
            dir="auto"
            type="text"
            :placeholder="s__('Analytics|Enter a visualization title')"
            :aria-label="s__('Analytics|Visualization title')"
            class="form-control gl-mr-4 gl-border-gray-200"
            data-testid="visualization-title-input"
            :state="!titleValidationError"
            required
            @input="validateTitle"
          />
        </gl-form-group>
        <gl-form-group
          :label="s__('Analytics|Visualization type')"
          class="gl-w-full gl-md-max-w-70p gl-lg-w-30p gl-min-w-20 gl-m-0"
          data-testid="visualization-type-form-group"
          :invalid-feedback="typeValidationError"
          :state="!typeValidationError"
        >
          <visualization-type-selector
            ref="typeSelector"
            data-testid="visualization-type-dropdown"
            :selected-visualization-type="selectedVisualizationType"
            @selectVisualizationType="selectVisualizationType"
          />
        </gl-form-group>
      </div>
    </section>
    <ai-cube-query-generator
      v-if="aiGenerateCubeQueryEnabled"
      v-model="aiPrompt"
      :warn-before-replacing-query="queryStateHasChanges"
      class="gl-mb-4"
      @query-generated="onQueryGenerated"
    />
    <section class="gl-border-t gl-border-b gl-mb-6">
      <query-builder
        ref="builder"
        :cube-api="cubeApi"
        :initial-viz-state="queryState"
        :query="queryState.query"
        :wrap-with-query-renderer="true"
        :disable-heuristics="true"
        data-testid="query-builder"
        class="gl-display-flex gl-flex-wrap"
        @queryStatus="onQueryStatusChange"
        @vizStateChange="onVizStateChange"
      >
        <template
          #builder="{
            measures,
            setMeasures,
            dimensions,
            addDimensions,
            timeDimensions,
            removeDimensions,
            setTimeDimensions,
            removeTimeDimensions,
            filters,
            setFilters,
            addFilters,
            setSegments,
            availableMeasures,
          }"
        >
          <visualization-filtered-search
            v-if="filteringUiEnabled"
            :query="queryState.query"
            :available-measures="availableMeasures"
            data-testid="visualization-filtered-search"
            @input="onFilterChange"
            @submit="onFilterChange"
          />
          <div v-else class="gl-pr-4 gl-pb-5 gl-border-r">
            <measure-selector
              :query="queryState.query"
              :measures="measures"
              :set-measures="setMeasures"
              :filters="filters"
              :set-filters="setFilters"
              :add-filters="addFilters"
              :set-segments="setSegments"
              data-testid="panel-measure-selector"
              @measureSelected="measureUpdated"
            />

            <dimension-selector
              v-if="showDimensionSelector"
              :measure-type="queryState.measureType"
              :query="queryState.query"
              :dimensions="dimensions"
              :add-dimensions="addDimensions"
              :remove-dimension="removeDimensions"
              :time-dimensions="timeDimensions"
              :set-time-dimensions="setTimeDimensions"
              :remove-time-dimension="removeTimeDimensions"
              data-testid="panel-dimension-selector"
            />
          </div>
        </template>

        <template #default="{ resultSet, isQueryPresent, loading }">
          <div class="gl-flex-grow-1 gl-bg-gray-10 gl-overflow-auto">
            <visualization-preview
              :selected-visualization-type="selectedVisualizationType"
              :display-type="selectedDisplayType"
              :is-query-present="isQueryPresent ? isQueryPresent : false"
              :loading="loading"
              :result-set="resultSet ? resultSet : null"
              :result-visualization="resultSet && isQueryPresent ? resultVisualization : null"
              :title="visualizationTitle"
              :ai-prompt-correlation-id="aiPromptCorrelationId"
              @selectedDisplayType="selectDisplayType"
            />
          </div>
        </template>
      </query-builder>
    </section>
    <section>
      <gl-button
        :loading="isSaving"
        category="primary"
        variant="confirm"
        data-testid="visualization-save-btn"
        @click="saveVisualization"
        >{{ saveButtonText }}</gl-button
      >
      <gl-button category="secondary" @click="routeToDashboardList">{{ __('Cancel') }}</gl-button>
    </section>
  </div>
</template>
