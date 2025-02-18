<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlTruncate,
} from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import agentImagesQuery from 'ee/security_dashboard/graphql/queries/agent_images.query.graphql';
import projectImagesQuery from 'ee/security_dashboard/graphql/queries/project_images.query.graphql';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_IMAGES_VALUE } from '../../filters/constants';
import eventHub from '../event_hub';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlTruncate,
    QuerystringSync,
  },
  inject: {
    agentName: { default: '' },
    fullPath: { default: '' },
    projectFullPath: { default: '' },
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
  apollo: {
    images: {
      query() {
        return this.isAgentDashboard ? agentImagesQuery : projectImagesQuery;
      },
      variables() {
        return {
          agentName: this.agentName,
          projectPath: this.projectFullPath || this.fullPath,
        };
      },
      update(data) {
        const vulnerabilityImages = this.isAgentDashboard
          ? data.project?.clusterAgent?.vulnerabilityImages
          : data.project?.vulnerabilityImages;

        return vulnerabilityImages.nodes.map(({ name }) => ({ text: name, value: name, id: name }));
      },
      error() {
        createAlert({ message: this.$options.i18n.loadingError });
      },
    },
  },
  data() {
    return {
      selectedImages: this.value.data || [ALL_IMAGES_VALUE],
      images: [],
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedImages,
      };
    },
    items() {
      return [{ value: ALL_IMAGES_VALUE, text: s__('SecurityReports|All images') }, ...this.images];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selectedImages,
        maxOptionsShown: 2,
      });
    },
    isAgentDashboard() {
      return Boolean(this.agentName);
    },
    isLoading() {
      return this.$apollo.queries.images.loading;
    },
  },
  methods: {
    emitFiltersChanged() {
      eventHub.$emit('filters-changed', {
        image: this.selectedImages.filter((value) => value !== ALL_IMAGES_VALUE),
      });
    },
    resetSelected() {
      this.selectedImages = [ALL_IMAGES_VALUE];
      this.emitFiltersChanged();
    },
    updateSelectedFromQS(values) {
      // This happens when we clear the token and re-select `Images`
      // to open the dropdown. At that stage we simply want to wait
      // for the user to select new images.
      if (!values.length) {
        return;
      }

      this.selectedImages = values;
      this.emitFiltersChanged();
    },
    toggleSelected(selectedValue) {
      const allImagesSelected = selectedValue === ALL_IMAGES_VALUE;

      if (this.selectedImages.includes(selectedValue)) {
        this.selectedImages = this.selectedImages.filter((s) => s !== selectedValue);
      } else {
        this.selectedImages = this.selectedImages.filter((s) => s !== ALL_IMAGES_VALUE);
        this.selectedImages.push(selectedValue);
      }

      if (!this.selectedImages.length || allImagesSelected) {
        this.selectedImages = [ALL_IMAGES_VALUE];
      }
    },
    isImageSelected(name) {
      return this.selectedImages.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Image'),
    loadingError: s__('SecurityOrchestration|Failed to load images.'),
  },
};
</script>

<template>
  <querystring-sync querystring-key="image" :value="selectedImages" @input="updateSelectedFromQS">
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedImages"
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
        <gl-loading-icon v-if="isLoading" size="sm" />
        <gl-filtered-search-suggestion
          v-for="image in items"
          v-else
          :key="image.value"
          :value="image.value"
        >
          <div class="gl-display-flex gl-align-items-center">
            <gl-icon
              name="check"
              class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
              :class="{ 'gl-invisible': !isImageSelected(image.value) }"
              :data-testid="`image-icon-${image.value}`"
            />
            <gl-truncate position="middle" :text="image.text" data-testid="truncate-image" />
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
