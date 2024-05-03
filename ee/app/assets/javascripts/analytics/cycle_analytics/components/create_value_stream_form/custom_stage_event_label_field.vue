<script>
import { GlButton, GlIcon, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapGetters, mapState } from 'vuex';
import { __ } from '~/locale';
import { getGroupLabels } from 'ee/api/analytics_api';
import { DATA_REFETCH_DELAY } from '../../../shared/constants';

export default {
  name: 'CustomStageEventLabelField',
  components: {
    GlButton,
    GlIcon,
    GlFormGroup,
    GlCollapsibleListbox,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    eventType: {
      type: String,
      required: true,
    },
    selectedLabelId: {
      type: Number,
      required: false,
      default: null,
    },
    fieldLabel: {
      type: String,
      required: true,
    },
    requiresLabel: {
      type: Boolean,
      required: true,
    },
    hasLabelError: {
      type: Boolean,
      required: false,
      default: false,
    },
    labelError: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      labels: [],
      searchTerm: '',
      loading: false,
      searching: false,
    };
  },
  computed: {
    ...mapState(['defaultGroupLabels']),
    fieldName() {
      const { eventType, index } = this;
      return `custom-stage-${eventType}-label-${index}`;
    },
    items() {
      return this.labels.map(({ id, title, color }) => ({ value: id, text: title, color }));
    },
    selectedLabel() {
      return this.labels.find(({ id }) => id === this.selectedLabelId);
    },
    selected: {
      get() {
        return this.selectedLabelId;
      },
      set(id) {
        this.$emit('update-label', { id });
      },
    },
  },
  watch: {
    searchTerm: debounce(function debouncedSearch() {
      this.search();
    }, DATA_REFETCH_DELAY),
  },
  async mounted() {
    if (!this.defaultGroupLabels?.length) {
      this.loading = true;
      await this.fetchLabels();
      this.loading = false;
    } else {
      this.labels = this.defaultGroupLabels;
    }
  },
  methods: {
    ...mapGetters(['namespacePath']),
    async fetchLabels() {
      try {
        const { data } = await getGroupLabels(this.namespacePath, {
          search: this.searchTerm,
          only_group_labels: true,
        });

        this.labels = data;
      } catch {
        this.$emit('error', this.$options.i18n.fetchError);
      }
    },
    async search() {
      this.searching = true;
      await this.fetchLabels();
      this.searching = false;
    },
  },
  i18n: {
    headerText: __('Select a label'),
    fetchError: __('There was an error fetching label data for the selected group'),
  },
};
</script>
<template>
  <div class="gl-w-1/2 gl-ml-2">
    <transition name="fade">
      <gl-form-group
        v-if="requiresLabel"
        :data-testid="fieldName"
        :label="fieldLabel"
        :state="hasLabelError"
        :invalid-feedback="labelError"
      >
        <gl-collapsible-listbox
          v-model="selected"
          block
          searchable
          :name="fieldName"
          :header-text="$options.i18n.headerText"
          :searching="searching"
          :items="items"
          @search="searchTerm = arguments[0]"
        >
          <template #toggle>
            <gl-button
              data-testid="listbox-toggle-btn"
              block
              button-text-classes="gl-w-full gl-display-flex gl-justify-content-space-between"
              :loading="loading"
            >
              <div v-if="selectedLabel">
                <span
                  :style="{ backgroundColor: selectedLabel.color }"
                  class="gl-display-inline-block dropdown-label-box"
                >
                </span>
                {{ selectedLabel.title }}
              </div>
              <div v-else class="gl-text-gray-500">{{ $options.i18n.headerText }}</div>
              <gl-icon name="chevron-down" />
            </gl-button>
          </template>
          <template #list-item="{ item: { text, color } }">
            <span
              :style="{ backgroundColor: color }"
              class="gl-display-inline-block dropdown-label-box"
            >
            </span>
            {{ text }}
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
    </transition>
  </div>
</template>
