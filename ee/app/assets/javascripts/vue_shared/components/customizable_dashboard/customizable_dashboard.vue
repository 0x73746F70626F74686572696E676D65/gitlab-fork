<script>
import { GlButton, GlFormInput, GlFormGroup, GlLink, GlIcon, GlSprintf } from '@gitlab/ui';
import { isEqual } from 'lodash';
import { createAlert } from '~/alert';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import { slugify } from '~/lib/utils/text_utility';
import { s__, __ } from '~/locale';
import { InternalEvents } from '~/tracking';
import UrlSync, { HISTORY_REPLACE_UPDATE_METHOD } from '~/vue_shared/components/url_sync.vue';
import BetaBadge from '~/vue_shared/components/badges/beta_badge.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { createNewVisualizationPanel } from 'ee/analytics/analytics_dashboards/utils';
import {
  AI_IMPACT_DASHBOARD,
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
} from 'ee/analytics/dashboards/constants';
import {
  EVENT_LABEL_VIEWED_DASHBOARD_DESIGNER,
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  DASHBOARD_STATUS_BETA,
} from 'ee/analytics/analytics_dashboards/constants';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { helpPagePath } from '~/helpers/help_page_helper';
import GridstackWrapper from './gridstack_wrapper.vue';
import AvailableVisualizationsDrawer from './dashboard_editor/available_visualizations_drawer.vue';
import {
  getDashboardConfig,
  filtersToQueryParams,
  availableVisualizationsValidator,
} from './utils';

export default {
  name: 'CustomizableDashboard',
  components: {
    DateRangeFilter: () => import('./filters/date_range_filter.vue'),
    AnonUsersFilter: () => import('./filters/anon_users_filter.vue'),
    GlButton,
    GlFormInput,
    GlIcon,
    GlLink,
    GlFormGroup,
    GlSprintf,
    UrlSync,
    BetaBadge,
    AvailableVisualizationsDrawer,
    GridstackWrapper,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  props: {
    initialDashboard: {
      type: Object,
      required: true,
      default: () => {},
    },
    availableVisualizations: {
      type: Object,
      required: false,
      default: () => {},
      validator: availableVisualizationsValidator,
    },
    dateRangeLimit: {
      type: Number,
      required: false,
      default: 0,
    },
    showDateRangeFilter: {
      type: Boolean,
      required: false,
      default: false,
    },
    showAnonUsersFilter: {
      type: Boolean,
      required: false,
      default: false,
    },
    defaultFilters: {
      type: Object,
      required: false,
      default: () => {},
    },
    syncUrlFilters: {
      type: Boolean,
      required: false,
      default: false,
    },
    isSaving: {
      type: Boolean,
      required: false,
      default: false,
    },
    changesSaved: {
      type: Boolean,
      required: false,
      default: false,
    },
    isNewDashboard: {
      type: Boolean,
      required: false,
      default: false,
    },
    titleValidationError: {
      type: String,
      required: false,
      default: null,
    },
    overviewCountsAggregationEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      dashboard: this.createDraftDashboard(this.initialDashboard),
      editing: this.isNewDashboard,
      filters: this.defaultFilters,
      alert: null,
      visualizationDrawerOpen: false,
    };
  },
  computed: {
    showFilters() {
      return !this.editing && (this.showDateRangeFilter || this.showAnonUsersFilter);
    },
    queryParams() {
      return this.showFilters ? filtersToQueryParams(this.filters) : {};
    },
    editingEnabled() {
      return (
        this.dashboard.userDefined &&
        (this.dashboard.slug !== CUSTOM_VALUE_STREAM_DASHBOARD ||
          this.glFeatures.enableVsdVisualEditor)
      );
    },
    showEditControls() {
      return this.editingEnabled && this.editing;
    },
    showDashboardDescription() {
      return Boolean(this.dashboard.description) && !this.editing;
    },
    showEditDashboardButton() {
      return this.editingEnabled && !this.editing;
    },
    dashboardHasUsageOverviewPanel() {
      return this.dashboard.panels
        .map(({ visualization: { slug } }) => slug)
        .includes('usage_overview');
    },
    showEnableAggregationWarning() {
      return this.dashboardHasUsageOverviewPanel && !this.overviewCountsAggregationEnabled;
    },
    showBetaBadge() {
      return this.dashboard.status === DASHBOARD_STATUS_BETA;
    },
    dashboardDescription() {
      return this.dashboard.description;
    },
    changesMade() {
      // Compare the dashboard configs as that is what will be saved
      return !isEqual(
        getDashboardConfig(this.initialDashboard),
        getDashboardConfig(this.dashboard),
      );
    },
    isValueStreamsDashboard() {
      return this.dashboard.slug === BUILT_IN_VALUE_STREAM_DASHBOARD;
    },
    isAiImpactDashboard() {
      return this.dashboard.slug === AI_IMPACT_DASHBOARD;
    },
  },
  watch: {
    isNewDashboard(isNew) {
      this.editing = isNew;
    },
    changesSaved: {
      handler(saved) {
        if (saved && this.editing) {
          this.editing = false;
        }
      },
      immediate: true,
    },
    '$route.params.editing': {
      handler(editing) {
        if (editing !== undefined) {
          this.editing = editing;
        }
      },
      immediate: true,
    },
    editing: {
      handler(editing) {
        this.grid?.setStatic(!editing);
        if (!editing) {
          this.closeVisualizationDrawer();
        } else {
          this.trackEvent(EVENT_LABEL_VIEWED_DASHBOARD_DESIGNER);
        }
      },
      immediate: true,
    },
    initialDashboard() {
      this.resetToInitialDashboard();
    },
  },
  mounted() {
    const wrappers = document.querySelectorAll('.container-fluid.container-limited');

    wrappers.forEach((el) => {
      el.classList.add('not-container-limited');
      el.classList.remove('container-limited');
    });

    window.addEventListener('beforeunload', this.onPageUnload);
  },
  beforeDestroy() {
    const wrappers = document.querySelectorAll('.container-fluid.not-container-limited');

    wrappers.forEach((el) => {
      el.classList.add('container-limited');
      el.classList.remove('not-container-limited');
    });

    this.alert?.dismiss();

    window.removeEventListener('beforeunload', this.onPageUnload);
  },
  methods: {
    onPageUnload(event) {
      if (!this.changesMade) return undefined;

      event.preventDefault();
      // This returnValue is required on some browsers. This message is displayed on older versions.
      // https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event#compatibility_notes
      const returnValue = __('Are you sure you want to lose unsaved changes?');
      Object.assign(event, { returnValue });
      return returnValue;
    },
    createDraftDashboard(dashboard) {
      return cloneWithoutReferences(dashboard);
    },
    resetToInitialDashboard() {
      this.dashboard = this.createDraftDashboard(this.initialDashboard);
    },
    onTitleInput(submitting) {
      this.$emit('title-input', this.dashboard.title, submitting);
    },
    startEdit() {
      this.editing = true;
    },
    async saveEdit() {
      if (this.titleValidationError === null && this.isNewDashboard) {
        // ensure validation gets run when form is submitted with an empty title
        this.onTitleInput(true);
        this.$refs.titleInput.$el.focus();
        return;
      }

      if (this.titleValidationError) {
        this.$refs.titleInput.$el.focus();
        return;
      }

      if (this.isNewDashboard && this.dashboard.panels.length < 1) {
        this.alert = createAlert({
          message: s__('Analytics|Add a visualization'),
        });
        return;
      }

      this.alert?.dismiss();

      if (this.isNewDashboard) {
        this.dashboard.slug = slugify(this.dashboard.title, '_');
      }

      this.$emit('save', this.dashboard.slug, this.dashboard);
    },
    async confirmDiscardIfChanged() {
      // Implicityly confirm if no changes were made
      if (!this.changesMade) return true;

      // No need to confirm while saving
      if (this.isSaving) return true;

      return this.confirmDiscardChanges();
    },
    async cancelEdit() {
      if (this.changesMade) {
        const confirmed = await this.confirmDiscardChanges();

        if (!confirmed) return;

        this.resetToInitialDashboard();
      }

      if (this.isNewDashboard) {
        this.$router.push('/');
        return;
      }

      this.editing = false;
    },
    async confirmDiscardChanges() {
      const confirmText = this.isNewDashboard
        ? s__('Analytics|Are you sure you want to cancel creating this dashboard?')
        : s__('Analytics|Are you sure you want to cancel editing this dashboard?');

      const cancelBtnText = this.isNewDashboard
        ? s__('Analytics|Continue creating')
        : s__('Analytics|Continue editing');

      return confirmAction(confirmText, {
        primaryBtnText: __('Discard changes'),
        cancelBtnText,
      });
    },
    setDateRangeFilter({ dateRangeOption, startDate, endDate }) {
      this.filters = {
        ...this.filters,
        dateRangeOption,
        startDate,
        endDate,
      };
    },
    setAnonymousUsersFilter(filterAnonUsers) {
      this.filters = {
        ...this.filters,
        filterAnonUsers,
      };

      if (filterAnonUsers) {
        this.trackEvent(EVENT_LABEL_EXCLUDE_ANONYMISED_USERS);
      }
    },
    toggleVisualizationDrawer() {
      this.visualizationDrawerOpen = !this.visualizationDrawerOpen;
    },
    closeVisualizationDrawer() {
      this.visualizationDrawerOpen = false;
    },
    deletePanel(panel) {
      const removeIndex = this.dashboard.panels.findIndex((p) => p.id === panel.id);
      this.dashboard.panels.splice(removeIndex, 1);
    },
    addPanels(visualizations) {
      this.closeVisualizationDrawer();

      const panels = visualizations.map((viz) => createNewVisualizationPanel(viz));
      this.dashboard.panels.push(...panels);
    },
  },
  i18n: {
    alternativeAiImpactDescription: s__(
      'Analytics|Visualize the relation between AI usage and SDLC trends. Learn more about %{docsLinkStart}AI Impact analytics%{docsLinkEnd} and %{subscriptionLinkStart}GitLab Duo Pro seats usage%{subscriptionLinkEnd}.',
    ),
  },
  HISTORY_REPLACE_UPDATE_METHOD,
  FORM_GROUP_CLASS: 'gl-w-full gl-sm-w-30p gl-min-w-20 gl-m-0',
  FORM_INPUT_CLASS: 'form-control gl-mr-4 gl-border-gray-200',
  VSD_DOCUMENTATION_LINK: helpPagePath('user/analytics/value_streams_dashboard'),
  AI_IMPACT_DOCUMENTATION_LINK: helpPagePath('user/analytics/value_streams_dashboard', {
    anchor: 'ai-impact-analytics',
  }),
  DUO_PRO_SUBSCRIPTION_ADD_ON_LINK: helpPagePath('subscriptions/subscription-add-ons', {
    anchor: 'assign-gitlab-duo-pro-seats',
  }),
};
</script>

<template>
  <div>
    <section class="gl-display-flex gl-align-items-center gl-my-4">
      <div class="gl-display-flex gl-flex-direction-column gl-w-full">
        <h2 v-if="showEditControls" data-testid="edit-mode-title" class="gl-mt-0 gl-mb-6">
          {{
            isNewDashboard
              ? s__('Analytics|Create your dashboard')
              : s__('Analytics|Edit your dashboard')
          }}
        </h2>
        <div v-else class="gl-display-flex gl-align-items-center">
          <h2 data-testid="dashboard-title" class="gl-my-0">{{ dashboard.title }}</h2>
          <beta-badge v-if="showBetaBadge" class="gl-ml-3" />
        </div>

        <div
          v-if="showDashboardDescription"
          class="gl-display-flex gl-mt-3"
          data-testid="dashboard-description"
        >
          <p class="gl-mb-0">
            <!-- TODO: Remove this alternative description in https://gitlab.com/gitlab-org/gitlab/-/issues/465569 -->
            <gl-sprintf
              v-if="isAiImpactDashboard"
              :message="$options.i18n.alternativeAiImpactDescription"
            >
              <template #docsLink="{ content }">
                <gl-link :href="$options.AI_IMPACT_DOCUMENTATION_LINK">{{ content }}</gl-link>
              </template>

              <template #subscriptionLink="{ content }">
                <gl-link :href="$options.DUO_PRO_SUBSCRIPTION_ADD_ON_LINK">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
            <template v-else>
              {{ dashboardDescription }}
              <!-- TODO: Remove this link in https://gitlab.com/gitlab-org/gitlab/-/issues/465569 -->
              <gl-sprintf
                v-if="isValueStreamsDashboard"
                :message="__('%{linkStart} Learn more%{linkEnd}.')"
              >
                <template #link="{ content }">
                  <gl-link :href="$options.VSD_DOCUMENTATION_LINK">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </template>
          </p>
        </div>

        <div v-if="showEditControls" class="gl-display-flex flex-fill gl-flex-direction-column">
          <gl-form-group
            :label="s__('Analytics|Dashboard title')"
            label-for="title"
            :class="$options.FORM_GROUP_CLASS"
            class="gl-mb-4"
            data-testid="dashboard-title-form-group"
            :invalid-feedback="titleValidationError"
            :state="!titleValidationError"
          >
            <gl-form-input
              id="title"
              ref="titleInput"
              v-model="dashboard.title"
              dir="auto"
              type="text"
              :placeholder="s__('Analytics|Enter a dashboard title')"
              :aria-label="s__('Analytics|Dashboard title')"
              :class="$options.FORM_INPUT_CLASS"
              data-testid="dashboard-title-input"
              :state="!titleValidationError"
              required
              @input="onTitleInput"
            />
          </gl-form-group>
          <gl-form-group
            :label="s__('Analytics|Dashboard description (optional)')"
            label-for="description"
            :class="$options.FORM_GROUP_CLASS"
          >
            <gl-form-input
              id="description"
              v-model="dashboard.description"
              dir="auto"
              type="text"
              :placeholder="s__('Analytics|Enter a dashboard description')"
              :aria-label="s__('Analytics|Dashboard description')"
              :class="$options.FORM_INPUT_CLASS"
              data-testid="dashboard-description-input"
            />
          </gl-form-group>
        </div>
      </div>

      <gl-button
        v-if="showEditDashboardButton"
        icon="pencil"
        class="gl-mr-2"
        data-testid="dashboard-edit-btn"
        @click="startEdit"
        >{{ s__('Analytics|Edit') }}</gl-button
      >
    </section>
    <div class="-gl-mx-3">
      <div class="gl-display-flex">
        <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-1">
          <section
            v-if="showFilters"
            data-testid="dashboard-filters"
            class="gl-display-flex gl-pt-4 gl-pb-3 gl-px-3 gl-flex-direction-column gl-md-flex-direction-row gl-gap-5"
          >
            <date-range-filter
              v-if="showDateRangeFilter"
              :default-option="filters.dateRangeOption"
              :start-date="filters.startDate"
              :end-date="filters.endDate"
              :date-range-limit="dateRangeLimit"
              @change="setDateRangeFilter"
            />
            <anon-users-filter
              v-if="showAnonUsersFilter"
              :value="filters.filterAnonUsers"
              @change="setAnonymousUsersFilter"
            />
          </section>
          <url-sync
            v-if="syncUrlFilters"
            :query="queryParams"
            :history-update-method="$options.HISTORY_REPLACE_UPDATE_METHOD"
          />
          <button
            v-if="showEditControls"
            class="card upload-dropzone-card upload-dropzone-border gl-display-flex gl-align-items-center gl-px-5 gl-py-3 gl-m-3"
            data-testid="add-visualization-button"
            @click="toggleVisualizationDrawer"
          >
            <div class="gl-font-bold gl-text-gray-700 gl-display-flex gl-align-items-center">
              <div
                class="gl-h-7 gl-w-7 gl-rounded-full gl-bg-gray-100 gl-inline-flex gl-align-items-center gl-justify-content-center gl-mr-3"
              >
                <gl-icon name="plus" />
              </div>
              {{ s__('Analytics|Add visualization') }}
            </div>
          </button>
          <gridstack-wrapper v-model="dashboard" :editing="editing">
            <template #panel="{ panel }">
              <slot
                name="panel"
                v-bind="{ panel, filters, editing, deletePanel: () => deletePanel(panel) }"
              ></slot>
            </template>
          </gridstack-wrapper>

          <available-visualizations-drawer
            :visualizations="availableVisualizations.visualizations"
            :loading="availableVisualizations.loading"
            :has-error="availableVisualizations.hasError"
            :open="visualizationDrawerOpen"
            @select="addPanels"
            @close="closeVisualizationDrawer"
          />
        </div>
      </div>
    </div>
    <template v-if="editing">
      <gl-button
        :loading="isSaving"
        class="gl-my-4 gl-mr-2"
        category="primary"
        variant="confirm"
        data-testid="dashboard-save-btn"
        @click="saveEdit"
        >{{ s__('Analytics|Save your dashboard') }}</gl-button
      >
      <gl-button category="secondary" data-testid="dashboard-cancel-edit-btn" @click="cancelEdit">{{
        s__('Analytics|Cancel')
      }}</gl-button>
    </template>
  </div>
</template>
