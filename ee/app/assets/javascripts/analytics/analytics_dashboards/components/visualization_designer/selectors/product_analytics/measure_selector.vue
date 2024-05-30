<script>
import { GlLabel, GlButton } from '@gitlab/ui';
import {
  EVENTS_TABLE_NAME,
  SESSIONS_TABLE_NAME,
  RETURNING_USERS_TABLE_NAME,
  MEASURE_COLOR,
  isRestrictedToEventType,
} from 'ee/analytics/analytics_dashboards/constants';
import VisualizationDesignerListOption from '../../visualization_designer_list_option.vue';

export default {
  name: 'ProductAnalyticsMeasureSelector',
  MEASURE_COLOR,
  components: {
    GlLabel,
    GlButton,
    VisualizationDesignerListOption,
  },
  props: {
    query: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    measures: {
      type: Array,
      required: true,
    },
    setMeasures: {
      type: Function,
      required: true,
    },
    filters: {
      type: Array,
      required: true,
    },
    setFilters: {
      type: Function,
      required: true,
    },
    addFilters: {
      type: Function,
      required: true,
    },
    setSegments: {
      type: Function,
      required: true,
    },
  },
  data() {
    return {
      measureType: '',
      measureSubType: '',
    };
  },
  watch: {
    query(query) {
      this.selectMeasureFromQuery(query);
    },
  },
  methods: {
    addSegment(measureSubType) {
      const segmentMap = {
        allSessionsCount: [`${RETURNING_USERS_TABLE_NAME}.returningUsers`],
      };
      const segments = segmentMap[measureSubType];

      if (segments?.length > 0) {
        this.setSegments(segments);
      }
    },
    addEventTypeFilter(measureType) {
      const eventTypeMap = {
        linkClickEvents: 'link_click',
        pageViews: 'page_view',
      };
      const selectedEventType = eventTypeMap[measureType];

      if (isRestrictedToEventType(measureType) && selectedEventType) {
        this.addFilters({
          member: `${EVENTS_TABLE_NAME}.eventName`,
          operator: 'equals',
          values: [selectedEventType],
        });
      }
    },
    selectMeasure(measureType, subMeasureType) {
      this.measureType = measureType;
      this.measureSubType = subMeasureType;

      // Reset fresh each time to prevent duplicate filters being added when the same query is applied multiple times
      this.setMeasures([]);
      this.setFilters([]);
      this.setSegments([]);

      if (this.measureType && this.measureSubType) {
        const measure = this.$options.MEASURE_MAP[this.measureType][this.measureSubType];
        this.setMeasures([measure]);

        this.addSegment(this.measureSubType);
        this.addEventTypeFilter(this.measureType);
      }

      this.$emit('measureSelected', this.measureType, this.measureSubType);
    },
    selectMeasureFromQuery(query) {
      const measure = query.measures?.at(0);

      if (!measure) {
        this.selectMeasure('', '');
        return;
      }

      for (const [measureType, subTypes] of Object.entries(this.$options.MEASURE_MAP)) {
        for (const [measureSubtype, measureVal] of Object.entries(subTypes)) {
          if (measureVal === measure) {
            this.selectMeasure(measureType, measureSubtype);
            return;
          }
        }
      }
    },
  },
  MEASURE_MAP: {
    pageViews: {
      all: `${EVENTS_TABLE_NAME}.pageViewsCount`,
    },
    linkClickEvents: {
      all: `${EVENTS_TABLE_NAME}.linkClicksCount`,
    },
    events: {
      all: `${EVENTS_TABLE_NAME}.count`,
    },
    uniqueUsers: {
      all: `${EVENTS_TABLE_NAME}.uniqueUsersCount`,
    },
    sessions: {
      count: `${SESSIONS_TABLE_NAME}.count`,
      averageDurationMinutes: `${SESSIONS_TABLE_NAME}.averageDurationMinutes`,
      averagePerUser: `${SESSIONS_TABLE_NAME}.averagePerUser`,
    },
    returningUsers: {
      allSessionsCount: `${RETURNING_USERS_TABLE_NAME}.allSessionsCount`,
      returningUserPercentage: `${RETURNING_USERS_TABLE_NAME}.returningUserPercentage`,
    },
  },
};
</script>

<template>
  <div>
    <div v-if="measureType && measureSubType" data-testid="measure-summary">
      <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Measuring') }}</h3>
      <gl-label
        :title="measureType + '::' + measureSubType"
        :background-color="$options.MEASURE_COLOR"
        scoped
        show-close-button
        @close="selectMeasure('', '')"
      />
    </div>
    <div v-else>
      <div v-if="!measureType">
        <h3 class="gl-font-xlg">
          {{ s__('ProductAnalytics|What metric do you want to visualize?') }}
        </h3>
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|User activity') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            icon="documents"
            data-testid="pageviews-button"
            :title="s__('ProductAnalytics|Page Views')"
            :description="s__('ProductAnalytics|Measure all or specific Page Views')"
            @click="selectMeasure('pageViews')"
          />
          <visualization-designer-list-option
            icon="check-circle"
            data-testid="linkclickevents-button"
            :title="s__('ProductAnalytics|Link Click Events')"
            :description="s__('ProductAnalytics|Measure all link click events')"
            @click="selectMeasure('linkClickEvents')"
          />
          <visualization-designer-list-option
            icon="monitor-lines"
            data-testid="events-button"
            :title="s__('ProductAnalytics|Events')"
            :description="s__('ProductAnalytics|Measure All tracked Events')"
            @click="selectMeasure('events')"
          />
        </ul>
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Users') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            icon="users"
            data-testid="users-button"
            :title="s__('ProductAnalytics|Unique Users')"
            :description="s__('ProductAnalytics|Measure by unique users')"
            @click="selectMeasure('uniqueUsers', 'all')"
          />
        </ul>
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|User Sessions') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="sessions-button"
            :title="s__('ProductAnalytics|Sessions')"
            :description="s__('ProductAnalytics|Measure all sessions')"
            @click="selectMeasure('sessions')"
          />
        </ul>
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Returning Users') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="returning-users-button"
            :title="s__('ProductAnalytics|Returning Users')"
            :description="s__('ProductAnalytics|Measure all returning users')"
            @click="selectMeasure('returningUsers')"
          />
        </ul>
      </div>
      <div v-else-if="measureType === 'pageViews'">
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Page Views') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="pageviews-all-button"
            :title="s__('ProductAnalytics|All Pages')"
            :description="
              s__('ProductAnalytics|Compares page views of all pages against each other')
            "
            @click="selectMeasure('pageViews', 'all')"
          />
        </ul>
      </div>

      <div v-else-if="measureType === 'linkClickEvents'">
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Link Click Events') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="linkclickevents-all-button"
            :title="s__('ProductAnalytics|All Link Clicks')"
            :description="s__('ProductAnalytics|Compares link click events against each other')"
            @click="selectMeasure('linkClickEvents', 'all')"
          />
        </ul>
      </div>
      <div v-else-if="measureType === 'events'">
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Events') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="events-all-button"
            :title="s__('ProductAnalytics|All Events Compared')"
            :description="s__('ProductAnalytics|Compares all events against each other')"
            @click="selectMeasure('events', 'all')"
          />
        </ul>
      </div>
      <div v-else-if="measureType === 'sessions'">
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Sessions') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="sessions-count-button"
            :title="s__('ProductAnalytics|All Sessions Compared')"
            :description="s__('ProductAnalytics|Compares all user sessions against each other')"
            @click="selectMeasure('sessions', 'count')"
          />
          <visualization-designer-list-option
            data-testid="sessions-avgduration-button"
            :title="s__('ProductAnalytics|Average Session Duration')"
            :description="s__('ProductAnalytics|Average duration in minutes')"
            @click="selectMeasure('sessions', 'averageDurationMinutes')"
          />
          <visualization-designer-list-option
            data-testid="sessions-avgperuser-button"
            :title="s__('ProductAnalytics|Average Per User')"
            :description="s__('ProductAnalytics|How many sessions a user has')"
            @click="selectMeasure('sessions', 'averagePerUser')"
          />
        </ul>
      </div>
      <div v-else-if="measureType === 'returningUsers'">
        <h3 class="gl-font-lg">{{ s__('ProductAnalytics|Returning Users') }}</h3>
        <ul class="content-list">
          <visualization-designer-list-option
            data-testid="returning-users-count-button"
            :title="s__('ProductAnalytics|All Returning Users Compared')"
            :description="s__('ProductAnalytics|Compares all returning users against each other')"
            @click="selectMeasure('returningUsers', 'allSessionsCount')"
          />
          <visualization-designer-list-option
            data-testid="returning-users-percentage-button"
            :title="s__('ProductAnalytics|Percentage of Users Returning')"
            :description="s__('ProductAnalytics|How often users returned compared to all sessions')"
            @click="selectMeasure('returningUsers', 'returningUserPercentage')"
          />
        </ul>
      </div>
      <div v-if="measureType" class="gl-mt-6">
        <gl-button data-testid="measure-back-button" @click="selectMeasure('')">{{
          __('Back')
        }}</gl-button>
      </div>
    </div>
  </div>
</template>
