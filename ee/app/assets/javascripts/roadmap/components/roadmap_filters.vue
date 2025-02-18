<script>
import { GlButton } from '@gitlab/ui';

import { updateHistory, setUrlParams } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';

import EpicsFilteredSearchMixin from '../mixins/filtered_search_mixin';
import { mapLocalSettings } from '../utils/roadmap_utils';

export default {
  availableSortOptions: [
    {
      id: 1,
      title: __('Start date'),
      sortDirection: {
        descending: 'START_DATE_DESC',
        ascending: 'START_DATE_ASC',
      },
    },
    {
      id: 2,
      title: __('Due date'),
      sortDirection: {
        descending: 'END_DATE_DESC',
        ascending: 'END_DATE_ASC',
      },
    },
    {
      id: 3,
      title: __('Title'),
      sortDirection: {
        descending: 'TITLE_DESC',
        ascending: 'TITLE_ASC',
      },
    },
    {
      id: 4,
      title: __('Created date'),
      sortDirection: {
        descending: 'CREATED_AT_DESC',
        ascending: 'CREATED_AT_ASC',
      },
    },
    {
      id: 5,
      title: __('Last updated date'),
      sortDirection: {
        descending: 'UPDATED_AT_DESC',
        ascending: 'UPDATED_AT_ASC',
      },
    },
  ],
  components: {
    GlButton,
    FilteredSearchBar,
  },
  mixins: [EpicsFilteredSearchMixin],
  data() {
    return {
      localRoadmapSettings: {},
    };
  },
  apollo: {
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'filterParams',
      'epicsState',
      'sortedBy',
      'timeframeRangeType',
      'isProgressTrackingActive',
      'progressTracking',
      'isShowingMilestones',
      'milestonesType',
      'isShowingLabels',
      'presetType',
    ]),
  },
  watch: {
    urlParams: {
      deep: true,
      immediate: true,
      handler(params) {
        if (Object.keys(params).length) {
          updateHistory({
            url: setUrlParams(params, window.location.href, true, false, true),
            title: document.title,
            replace: true,
          });
        }
      },
    },
  },
  methods: {
    setLocalSettings(settings) {
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: settings,
        },
      });
    },
    handleFilterEpics(filters, cleared) {
      if (filters.length || cleared) {
        this.setLocalSettings({ filterParams: this.getFilterParams(filters) });
      }
    },
    handleSortEpics(sortedBy) {
      this.setLocalSettings({ sortedBy });
    },
  },
  i18n: {
    settings: __('Settings'),
  },
};
</script>

<template>
  <div class="epics-filters epics-roadmap-filters epics-roadmap-filters-gl-ui gl-relative">
    <div
      class="epics-details-filters filtered-search-block gl-flex gl-flex-col sm:gl-flex-row gl-py-3 gl-px-5 xl:gl-px-6 row-content-block second-block sm:gl-gap-3"
    >
      <filtered-search-bar
        :namespace="groupFullPath"
        :tokens="getFilteredSearchTokens()"
        :sort-options="$options.availableSortOptions"
        :initial-filter-value="getFilteredSearchValue()"
        :initial-sort-by="sortedBy"
        sync-filter-and-sort
        terms-as-tokens
        recent-searches-storage-key="epics"
        class="gl-flex-grow-1"
        @onFilter="handleFilterEpics"
        @onSort="handleSortEpics"
      />
      <gl-button
        icon="settings"
        class="sm:gl-mt-0 gl-mt-3 !gl-shadow-inner-1-gray-400"
        :aria-label="$options.i18n.settings"
        data-testid="settings-button"
        @click="$emit('toggleSettings', $event)"
      >
        {{ $options.i18n.settings }}
      </gl-button>
    </div>
  </div>
</template>
