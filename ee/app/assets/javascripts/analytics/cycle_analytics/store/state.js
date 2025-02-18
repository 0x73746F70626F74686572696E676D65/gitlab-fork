import {
  PAGINATION_SORT_FIELD_DURATION,
  PAGINATION_SORT_DIRECTION_DESC,
} from '~/analytics/cycle_analytics/constants';

export default () => ({
  features: {},
  defaultStageConfig: [],
  defaultGroupLabels: null,

  createdAfter: null,
  createdBefore: null,
  predefinedDateRange: null,

  isLoading: false,
  isLoadingStage: false,

  errorCode: null,

  groupPath: null,
  selectedProjects: [],
  selectedStage: null,
  selectedValueStream: null,
  namespace: { name: null, fullPath: null },

  selectedStageEvents: [],

  isLoadingValueStreams: false,
  isCreatingValueStream: false,
  isEditingValueStream: false,
  isDeletingValueStream: false,
  isFetchingGroupLabels: false,
  isCreatingAggregation: false,
  isFetchingGroupStagesAndEvents: false,

  createValueStreamErrors: {},
  deleteValueStreamError: null,

  stages: [],
  formEvents: [],
  selectedStageError: '',
  summary: [],
  medians: {},
  valueStreams: [],

  pagination: {
    page: null,
    hasNextPage: false,
    sort: PAGINATION_SORT_FIELD_DURATION,
    direction: PAGINATION_SORT_DIRECTION_DESC,
  },
  stageCounts: {},
  aggregation: {
    enabled: false,
    lastRunAt: null,
    nextRunAt: null,
  },
  canEdit: false,
  enableVsdLink: false,
  enableTasksByTypeChart: false,
  enableCustomizableStages: false,
  enableProjectsFilter: false,
});
