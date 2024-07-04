<script>
import {
  GlBadge,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlIcon,
} from '@gitlab/ui';
import { without } from 'lodash';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_ACTIVITY_VALUE } from '../../filters/constants';
import { ITEMS } from '../../filters/activity_filter.vue';
import eventHub from '../event_hub';

const OPTIONS = Object.values(ITEMS);

const GROUPS = [
  {
    text: '',
    options: [
      {
        value: ALL_ACTIVITY_VALUE,
        text: s__('SecurityReports|All activity'),
      },
    ],
  },
  {
    text: s__('SecurityReports|Detection'),
    options: [ITEMS.STILL_DETECTED, ITEMS.NO_LONGER_DETECTED],
    icon: 'check-circle-dashed',
    variant: 'info',
  },
  {
    text: s__('SecurityReports|Issue'),
    options: [ITEMS.HAS_ISSUE, ITEMS.DOES_NOT_HAVE_ISSUE],
    icon: 'issues',
  },
  {
    text: s__('SecurityReports|Merge Request'),
    options: [ITEMS.HAS_MERGE_REQUEST, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST],
    icon: 'git-merge',
  },
  {
    text: s__('SecurityReports|Solution available'),
    options: [ITEMS.HAS_SOLUTION, ITEMS.DOES_NOT_HAVE_SOLUTION],
    icon: 'bulb',
  },
];

export default {
  DEFAULT_VALUES: [ITEMS.STILL_DETECTED.value],
  VALID_VALUES: [ALL_ACTIVITY_VALUE, ...OPTIONS.map(({ value }) => value)],
  GROUPS,
  queryStringDefaultValues: [ALL_ACTIVITY_VALUE],
  components: {
    GlBadge,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    GlIcon,
    QuerystringSync,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const defaultSelected = this.value.data || this.$options.DEFAULT_VALUES;

    return {
      selectedActivities: defaultSelected,
      querySyncValues: defaultSelected,
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedActivities,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: Object.values(ITEMS),
        selected: this.selectedActivities,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedActivities = [];
      this.emitFiltersChanged();
    },
    setSelectedValue(keyWhenTrue, keyWhenFalse) {
      // The variables can be true, false, or unset, so we need to use if/else-if here instead
      // of if/else.
      if (this.selectedActivities.includes(ITEMS[keyWhenTrue].value)) return true;
      if (this.selectedActivities.includes(ITEMS[keyWhenFalse].value)) return false;
      return undefined;
    },
    emitFiltersChanged() {
      this.querySyncValues = this.selectedActivities;
      eventHub.$emit('filters-changed', {
        hasResolution: this.setSelectedValue('NO_LONGER_DETECTED', 'STILL_DETECTED'),
        hasIssues: this.setSelectedValue('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE'),
        hasMergeRequest: this.setSelectedValue('HAS_MERGE_REQUEST', 'DOES_NOT_HAVE_MERGE_REQUEST'),
        hasRemediations: this.setSelectedValue('HAS_SOLUTION', 'DOES_NOT_HAVE_SOLUTION'),
      });
    },
    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_ACTIVITY_VALUE)) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
      } else if (selected.length > 0) {
        this.selectedActivities = selected;
      } else {
        // This happens when we clear the token and re-select `Status`
        // to open the dropdown. At that stage we simply want to wait
        // for the user to select new statuses.
        if (!this.value.data) {
          return;
        }

        this.selectedActivities = this.value.data || this.$options.DEFAULT_VALUES;
      }

      this.emitFiltersChanged();
    },
    getGroupFromItem(value) {
      return this.$options.GROUPS.find((group) =>
        group.options.map((option) => option.value).includes(value),
      );
    },
    toggleSelected(selectedValue) {
      const allActivitiesSelected = selectedValue === ALL_ACTIVITY_VALUE;

      if (allActivitiesSelected) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
        return;
      }

      const withoutSelectedValue = without(this.selectedActivities, selectedValue);
      const isSelecting = !this.selectedActivities.includes(selectedValue);
      // If a new item is selected, clear other selected items from the same group, clear all option and select the new item.
      if (isSelecting) {
        const group = this.getGroupFromItem(selectedValue);
        const groupItemValues = group.options.map((option) => option.value);
        this.selectedActivities = without(
          this.selectedActivities,
          ...groupItemValues,
          ALL_ACTIVITY_VALUE,
        ).concat(selectedValue);
      }
      // Otherwise, check whether selectedActivities would be empty and set based on that.
      else if (withoutSelectedValue.length === 0) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
      } else {
        this.selectedActivities = withoutSelectedValue;
      }
    },

    isActivitySelected(name) {
      return this.selectedActivities.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Activity'),
    allItemsText: s__('SecurityReports|All activity'),
  },
};
</script>

<template>
  <querystring-sync
    querystring-key="activity"
    :value="querySyncValues"
    :valid-values="$options.VALID_VALUES"
    :default-values="$options.queryStringDefaultValues"
    data-testid="activity-token"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedActivities"
      :value="tokenValue"
      v-on="$listeners"
      @select="toggleSelected"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        {{ toggleText }}
      </template>
      <template #suggestions>
        <template v-for="(group, index) in $options.GROUPS">
          <gl-dropdown-section-header v-if="group.text" :key="group.text"
            ><div
              v-if="group.icon"
              class="gl-flex gl-justify-center gl-items-center"
              :data-testid="`header-${group.text}`"
            >
              <div class="gl-flex-grow-1">{{ group.text }}</div>
              <gl-badge :icon="group.icon" :variant="group.variant" /></div
          ></gl-dropdown-section-header>
          <gl-filtered-search-suggestion
            v-for="activity in group.options"
            :key="activity.value"
            :value="activity.value"
          >
            <div class="gl-display-flex gl-align-items-center">
              <gl-icon
                name="check"
                class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
                :class="{ 'gl-invisible': !isActivitySelected(activity.value) }"
                :data-testid="`status-icon-${activity.value}`"
              />
              {{ activity.text }}
            </div>
          </gl-filtered-search-suggestion>
          <gl-dropdown-divider
            v-if="index < $options.GROUPS.length - 1"
            :key="`${group.text}-divider`"
          />
        </template>
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
