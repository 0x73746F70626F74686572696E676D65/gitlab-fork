<script>
import { GlIcon, GlTruncate, GlCollapsibleListbox, GlLink } from '@gitlab/ui';
import { debounce } from 'lodash';
import { n__, s__, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { filterPathBySearchTerm } from '../store/utils';
import { SEARCH_MIN_THRESHOLD } from './constants';

const mapItemToListboxFormat = (item, index) => ({
  ...item,
  value: index,
  text: item.location.path,
});

export default {
  name: 'DependencyLocationCount',
  components: {
    GlIcon,
    GlTruncate,
    GlCollapsibleListbox,
    GlLink,
  },
  inject: ['locationsEndpoint'],
  props: {
    locationCount: {
      type: Number,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      loading: true,
      locations: [],
      searchTerm: '',
    };
  },
  computed: {
    locationText() {
      const locationCount = this.locationCount || 0;
      return sprintf(
        n__(
          'Dependencies|%{locationCount} location',
          'Dependencies|%{locationCount} locations',
          locationCount,
        ),
        {
          locationCount,
        },
      );
    },
    availableLocations() {
      return filterPathBySearchTerm(this.locations, this.searchTerm);
    },
    searchEnabled() {
      return this.loading || this.locationCount > SEARCH_MIN_THRESHOLD;
    },
  },
  i18n: {
    unknownPath: s__('Dependencies|Unknown path'),
  },
  created() {
    this.search = debounce((searchTerm) => {
      this.searchTerm = searchTerm;
      this.fetchData();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    onHide() {
      this.searchTerm = '';
    },
    onShown() {
      this.search();
    },
    hasLocationPath(item) {
      return item.location.blob_path && item.location.path;
    },
    async fetchData() {
      this.loading = true;

      const {
        data: { locations },
      } = await axios.get(this.locationsEndpoint, {
        params: {
          search: this.searchTerm,
          component_id: this.componentId,
        },
      });

      this.loading = false;
      this.locations = locations.map(mapItemToListboxFormat);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="locationText"
    :items="availableLocations"
    :searching="loading"
    :searchable="searchEnabled"
    @hidden="onHide"
    @search="search"
    @shown="onShown"
  >
    <template #toggle>
      <span class="md:gl-whitespace-nowrap gl-text-blue-500">
        <gl-icon name="doc-text" />
        <gl-truncate
          class="gl-hidden md:gl-inline-flex"
          position="start"
          :text="locationText"
          with-tooltip
        />
      </span>
    </template>
    <template #list-item="{ item }">
      <div v-if="item">
        <div class="md:gl-whitespace-nowrap gl-text-blue-500">
          <gl-link
            v-if="hasLocationPath(item)"
            :href="item.location.blob_path"
            class="gl-hover-text-decoration-none"
          >
            <gl-icon name="doc-text" class="gl-absolute" />
            <gl-truncate position="start" :text="item.location.path" with-tooltip class="gl-pl-6" />
          </gl-link>
          <div v-else class="gl-text-gray-500" data-testid="unknown-path">
            <gl-icon name="error" class="gl-absolute" />
            <gl-truncate
              position="start"
              :text="$options.i18n.unknownPath"
              with-tooltip
              class="gl-pl-6"
            />
          </div>
        </div>
        <gl-truncate :text="item.project.name" class="gl-mt-2 gl-pl-6 gl-text-gray-500" />
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
