<script>
import { GlLink } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { getIterationPeriod, groupOptionsByIterationCadences } from 'ee/iterations/utils';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import projectIterationsQuery from 'ee/work_items/graphql/project_iterations.query.graphql';
import { STATUS_OPEN } from '~/issues/constants';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  I18N_WORK_ITEM_FETCH_ITERATIONS_ERROR,
  sprintfWorkItem,
  TRACKING_CATEGORY_SHOW,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';

export default {
  i18n: {
    iteration: s__('WorkItem|Iteration'),
    none: s__('WorkItem|None'),
    iterationPlaceholder: s__('WorkItem|No iteration'),
  },
  components: {
    WorkItemSidebarDropdownWidget,
    IterationTitle,
    GlLink,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIterationsFeature'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    iteration: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
      shouldFetch: false,
      selectedIterationId: this.iteration?.id,
      updateInProgress: false,
      iterations: [],
      localIteration: this.iteration,
    };
  },
  computed: {
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_iteration',
        property: `type_${this.workItemType}`,
      };
    },
    iterationPeriod() {
      return this.localIteration?.period || getIterationPeriod(this.localIteration);
    },
    iterationTitle() {
      return this.localIteration?.title || this.iterationPeriod;
    },
    listboxItems() {
      return groupOptionsByIterationCadences(this.iterations);
    },
    isLoadingIterations() {
      return this.$apollo.queries.iterations.loading;
    },
    noIterationDefaultText() {
      return this.canUpdate ? this.$options.i18n.iterationPlaceholder : this.$options.i18n.none;
    },
    dropdownText() {
      return this.localIteration?.id ? this.iterationTitle : this.noIterationDefaultText;
    },
    selectedIteration() {
      return !isEmpty(this.iterations)
        ? this.iterations.find(({ id }) => id === this.selectedIterationId)
        : this.localIteration;
    },
    selectedIterationCadenceName() {
      return this.selectedIteration?.iterationCadence?.title;
    },
    localIterationId() {
      return this.localIteration ? this.localIteration?.id : null;
    },
  },
  watch: {
    iteration(newVal) {
      this.localIteration = newVal;
      this.selectedIterationId = newVal?.id;
    },
  },
  apollo: {
    iterations: {
      query: projectIterationsQuery,
      variables() {
        const search = this.searchTerm ? `"${this.searchTerm}"` : '';
        return {
          fullPath: this.fullPath,
          title: search,
          state: STATUS_OPEN,
        };
      },
      update(data) {
        return data.workspace?.attributes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
      error() {
        this.$emit('error', I18N_WORK_ITEM_FETCH_ITERATIONS_ERROR);
      },
    },
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.shouldFetch = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.shouldFetch = true;
    },
    async updateWorkItemIteration(selectedIterationId) {
      if (this.iteration?.id === selectedIterationId) {
        return;
      }

      this.localIteration = selectedIterationId
        ? this.iterations.find(({ id }) => id === selectedIterationId)
        : null;
      this.selectedIterationId = selectedIterationId;
      this.track('update_iteration');

      this.updateInProgress = true;
      try {
        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              iterationWidget: {
                iterationId: selectedIterationId,
              },
            },
          },
        });
        this.track('updated_iteration');
        if (errors.length > 0) {
          throw new Error(errors.join('\n'));
        }
      } catch (error) {
        const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
        this.$emit('error', msg);
        this.localIteration = this.iteration;
        Sentry.captureException(error);
      } finally {
        this.updateInProgress = false;
        this.searchTerm = '';
        this.shouldFetch = false;
        this.selectedIterationId = selectedIterationId;
      }
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    v-if="hasIterationsFeature"
    :dropdown-label="$options.i18n.iteration"
    :can-update="canUpdate"
    dropdown-name="iteration"
    :loading="isLoadingIterations"
    :list-items="listboxItems"
    :item-value="localIterationId"
    :update-in-progress="updateInProgress"
    :toggle-dropdown-text="dropdownText"
    :header-text="__('Select iteration')"
    :reset-button-label="__('Clear')"
    data-testid="work-item-iteration"
    @dropdownShown="onDropdownShown"
    @searchStarted="search"
    @updateValue="updateWorkItemIteration"
  >
    <template #list-item="{ item }">
      <div>
        {{ item.text }}
      </div>
      <div v-if="item.title">{{ item.title }}</div>
    </template>
    <template #readonly>
      <div class="gl-text-gray-500 gl-mr-2">
        {{ selectedIterationCadenceName }}
      </div>
      <gl-link class="gl-text-gray-900!" :href="localIteration.webUrl">
        <div>
          {{ iterationPeriod }}
        </div>
        <iteration-title v-if="localIteration.title" :title="localIteration.title" />
      </gl-link>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
