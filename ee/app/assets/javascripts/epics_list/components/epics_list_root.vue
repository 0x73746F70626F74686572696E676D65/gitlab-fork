<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';

import EpicsFilteredSearchMixin from 'jh_else_ee/roadmap/mixins/filtered_search_mixin';
import groupEpics from 'jh_else_ee/epics_list/queries/group_epics.query.graphql';

import { createAlert } from '~/alert';

import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

import { issuableListTabs, DEFAULT_PAGE_SIZE } from '~/vue_shared/issuable/list/constants';
import { humanTimeframe } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';

import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC } from '~/work_items/constants';

import { transformFetchEpicFilterParams } from '../../roadmap/utils/epic_utils';
import { epicsSortOptions } from '../constants';

import EpicsListEmptyState from './epics_list_empty_state.vue';
import EpicsListBulkEditSidebar from './epics_list_bulk_edit_sidebar.vue';

export default {
  WORK_ITEM_TYPE_ENUM_EPIC,
  issuableListTabs,
  epicsSortOptions,
  defaultPageSize: DEFAULT_PAGE_SIZE,
  epicSymbol: '&',
  components: {
    CreateWorkItemModal,
    GlButton,
    GlIcon,
    IssuableList,
    EpicsListEmptyState,
    EpicsListBulkEditSidebar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [EpicsFilteredSearchMixin, glFeatureFlagsMixin()],
  inject: [
    'canCreateEpic',
    'canBulkEditEpics',
    'hasScopedLabelsFeature',
    'page',
    'prev',
    'next',
    'initialState',
    'initialSortBy',
    'epicNewPath',
    'groupFullPath',
    'listEpicsPath',
    'groupMilestonesPath',
    'emptyStatePath',
    'isSignedIn',
  ],
  apollo: {
    epics: {
      query: groupEpics,
      variables() {
        const queryVariables = {
          groupPath: this.groupFullPath,
          state: this.currentState,
          isSignedIn: this.isSignedIn,
        };

        if (this.prevPageCursor) {
          queryVariables.prevPageCursor = this.prevPageCursor;
          queryVariables.lastPageSize = this.$options.defaultPageSize;
        } else if (this.nextPageCursor) {
          queryVariables.nextPageCursor = this.nextPageCursor;
          queryVariables.firstPageSize = this.$options.defaultPageSize;
        } else {
          queryVariables.firstPageSize = this.$options.defaultPageSize;
        }

        if (this.sortedBy) {
          queryVariables.sortBy = this.sortedBy;
        }

        if (Object.keys(this.filterParams).length) {
          const transformedFilterParams = transformFetchEpicFilterParams(this.filterParams);

          Object.assign(queryVariables, {
            ...transformedFilterParams,
          });

          if (transformedFilterParams.groupPath) {
            queryVariables.groupPath = transformedFilterParams.groupPath;
            queryVariables.includeDescendantGroups = false;
          }
        }

        return queryVariables;
      },
      update(data) {
        const epicsRoot = data.group?.epics;

        return {
          list: epicsRoot?.nodes || [],
          pageInfo: epicsRoot?.pageInfo || {},
          opened: data.group?.totalOpenedEpics?.count,
          closed: data.group?.totalClosedEpics?.count,
          all: data.group?.totalEpics?.count,
        };
      },
      error(error) {
        createAlert({
          message: s__('Epics|Something went wrong while fetching epics list.'),
          captureError: true,
          error,
        });
      },
    },
  },
  props: {
    initialFilterParams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      currentState: this.initialState,
      currentPage: this.page,
      prevPageCursor: this.prev,
      nextPageCursor: this.next,
      filterParams: this.initialFilterParams,
      sortedBy: this.initialSortBy,
      showBulkEditSidebar: false,
      bulkEditInProgress: false,
      epics: {
        list: [],
        pageInfo: {},
      },
    };
  },
  computed: {
    searchTokens() {
      return this.getFilteredSearchTokens({
        supportsEpic: false,
      });
    },
    epicsCount() {
      const { opened, closed, all } = this.epics;
      return {
        opened,
        closed,
        all,
      };
    },
    epicsListLoading() {
      return this.$apollo.queries.epics.loading;
    },
    epicsListEmpty() {
      return !this.$apollo.queries.epics.loading && !this.epics.list.length;
    },
    showPaginationControls() {
      const { hasPreviousPage, hasNextPage } = this.epics.pageInfo;

      // This explicit check is necessary as both the variables
      // can also be `false` and we just want to ensure that they're present.
      if (hasPreviousPage !== undefined || hasNextPage !== undefined) {
        return Boolean(hasPreviousPage || hasNextPage);
      }
      return !this.epicsListEmpty;
    },
    previousPage() {
      return Math.max(this.currentPage - 1, 0);
    },
    nextPage() {
      const nextPage = this.currentPage + 1;
      return nextPage >
        Math.ceil(this.epicsCount[this.currentState] / this.$options.defaultPageSize)
        ? null
        : nextPage;
    },
  },
  methods: {
    epicReference(epic) {
      const reference = `${this.$options.epicSymbol}${epic.iid}`;
      if (epic.group.fullPath !== this.groupFullPath) {
        return `${epic.group.fullPath}${reference}`;
      }
      return reference;
    },
    epicTimeframe({ startDate, dueDate }) {
      return humanTimeframe(startDate, dueDate);
    },
    fetchEpicsBy(propsName, propValue) {
      if (propsName === 'currentPage') {
        const { startCursor, endCursor } = this.epics.pageInfo;

        if (propValue > this.currentPage) {
          this.prevPageCursor = '';
          this.nextPageCursor = endCursor;
        } else {
          this.prevPageCursor = startCursor;
          this.nextPageCursor = '';
        }
      } else if (propsName === 'currentState' || propsName === 'sortedBy') {
        this.currentPage = 1;
        this.prevPageCursor = '';
        this.nextPageCursor = '';
      }
      this[propsName] = propValue;
    },
    handleFilterEpics(filters) {
      this.filterParams = this.getFilterParams(filters);
    },
    /**
     * Bulk editing Issuables (or Epics in this case) is not supported
     * via GraphQL mutations, so we're using legacy API to do it,
     * hence we're making a POST call within the component.
     */
    handleEpicsBulkUpdate(update) {
      this.bulkEditInProgress = true;
      axios
        .post(`${this.listEpicsPath}/bulk_update`, {
          update,
        })
        .then(() => window.location.reload())
        .catch((error) => {
          createAlert({
            message: s__('Epics|Something went wrong while updating epics.'),
            captureError: true,
            error,
          });
        });
    },
    hasDateSet({ startDate, dueDate }) {
      return Boolean(startDate || dueDate);
    },
  },
};
</script>

<template>
  <issuable-list
    :namespace="groupFullPath"
    :tabs="$options.issuableListTabs"
    :current-tab="currentState"
    :tab-counts="epicsCount"
    :search-tokens="searchTokens"
    :sort-options="$options.epicsSortOptions"
    :has-scoped-labels-feature="hasScopedLabelsFeature"
    :initial-filter-value="getFilteredSearchValue()"
    :initial-sort-by="sortedBy"
    :issuables="epics.list"
    :issuables-loading="epicsListLoading"
    :show-bulk-edit-sidebar="showBulkEditSidebar"
    :show-pagination-controls="showPaginationControls"
    :show-discussions="true"
    :default-page-size="$options.defaultPageSize"
    :current-page="currentPage"
    :previous-page="previousPage"
    :next-page="nextPage"
    :url-params="urlParams"
    :issuable-symbol="$options.epicSymbol"
    recent-searches-storage-key="epics"
    @click-tab="fetchEpicsBy('currentState', $event)"
    @page-change="fetchEpicsBy('currentPage', $event)"
    @sort="fetchEpicsBy('sortedBy', $event)"
    @filter="handleFilterEpics"
  >
    <template v-if="canCreateEpic || canBulkEditEpics" #nav-actions>
      <div class="gl-display-flex gl-gap-3">
        <gl-button
          v-if="canBulkEditEpics"
          class="!gl-w-auto gl-flex-grow-1"
          :disabled="showBulkEditSidebar"
          @click="showBulkEditSidebar = true"
          >{{ __('Bulk edit') }}</gl-button
        >
        <create-work-item-modal
          v-if="canCreateEpic && glFeatures.namespaceLevelWorkItems"
          class="gl-flex-grow-1"
          :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
        />
        <gl-button
          v-else-if="canCreateEpic"
          category="primary"
          variant="confirm"
          class="!gl-w-auto gl-flex-grow-1"
          :href="epicNewPath"
          data-testid="new-epic-button"
          >{{ __('New epic') }}</gl-button
        >
      </div>
    </template>
    <template #bulk-edit-actions="{ checkedIssuables }">
      <gl-button
        category="primary"
        variant="confirm"
        type="submit"
        class="js-update-selected-issues"
        form="epics-list-bulk-edit"
        :disabled="checkedIssuables.length === 0 || bulkEditInProgress"
        :loading="bulkEditInProgress"
        >{{ __('Update selected') }}</gl-button
      >
      <gl-button class="gl-float-right" @click="showBulkEditSidebar = false">{{
        __('Cancel')
      }}</gl-button>
    </template>
    <template #sidebar-items="{ checkedIssuables }">
      <epics-list-bulk-edit-sidebar
        :checked-epics="checkedIssuables"
        @bulk-update="handleEpicsBulkUpdate"
      />
    </template>
    <template #reference="{ issuable }">
      <span data-testid="issuable-reference" class="issuable-reference">{{
        epicReference(issuable)
      }}</span>
    </template>
    <template #timeframe="{ issuable }">
      <gl-icon v-if="hasDateSet(issuable)" name="calendar" />
      {{ epicTimeframe(issuable) }}
    </template>
    <template #statistics="{ issuable = {} }">
      <li
        v-if="issuable.blockingCount"
        v-gl-tooltip
        class="gl-hidden sm:gl-block"
        :title="__('Blocking epics')"
        data-testid="issuable-blocking-count"
      >
        <gl-icon name="entity-blocked" />
        {{ issuable.blockingCount }}
      </li>
      <li
        v-if="issuable.upvotes"
        v-gl-tooltip
        class="gl-hidden sm:gl-block"
        :title="__('Upvotes')"
        data-testid="issuable-upvotes"
      >
        <gl-icon name="thumb-up" />
        {{ issuable.upvotes }}
      </li>
      <li
        v-if="issuable.downvotes"
        v-gl-tooltip
        class="gl-hidden sm:gl-block"
        :title="__('Downvotes')"
        data-testid="issuable-downvotes"
      >
        <gl-icon name="thumb-down" />
        {{ issuable.downvotes }}
      </li>
    </template>
    <template #empty-state>
      <epics-list-empty-state :current-state="currentState" :epics-count="epicsCount" />
    </template>
  </issuable-list>
</template>
