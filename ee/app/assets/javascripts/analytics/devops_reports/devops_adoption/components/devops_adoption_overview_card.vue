<script>
import { GlButton, GlIcon, GlProgressBar } from '@gitlab/ui';
import { sprintf } from '~/locale';
import { I18N_FEATURES_ADOPTED_TEXT, PROGRESS_BAR_HEIGHT } from '../constants';
import DevopsAdoptionTableCellFlag from './devops_adoption_table_cell_flag.vue';

export default {
  name: 'DevopsAdoptionOverviewCard',
  progressBarHeight: PROGRESS_BAR_HEIGHT,
  components: {
    GlButton,
    GlIcon,
    GlProgressBar,
    DevopsAdoptionTableCellFlag,
  },
  props: {
    icon: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    featureMeta: {
      type: Array,
      required: false,
      default: () => [],
    },
    displayMeta: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    featuresCount() {
      return this.featureMeta.length;
    },
    adoptedCount() {
      return this.featureMeta.filter((feature) => feature.adopted).length;
    },
    description() {
      return sprintf(I18N_FEATURES_ADOPTED_TEXT, {
        adoptedCount: this.adoptedCount,
        featuresCount: this.featuresCount,
        title: this.displayMeta ? this.title : '',
      });
    },
  },
  methods: {
    trackCardTitleClick() {
      this.$emit('card-title-clicked');
    },
  },
};
</script>
<template>
  <div
    class="devops-overview-card gl-display-flex gl-flex-direction-column gl-flex-grow-1 gl-md-mr-5 gl-mb-4"
  >
    <div class="gl-display-flex gl-align-items-center gl-mb-3" data-testid="card-title">
      <gl-icon :name="icon" class="gl-mr-3 gl-text-gray-500" />
      <gl-button
        v-if="displayMeta"
        class="gl-font-md gl-font-bold"
        variant="link"
        data-testid="card-title-link"
        @click="trackCardTitleClick"
        >{{ title }}
      </gl-button>
      <span v-else class="gl-font-md gl-font-bold">{{ title }} </span>
    </div>
    <gl-progress-bar
      :value="adoptedCount"
      :max="featuresCount"
      class="gl-mb-2 gl-md-mr-5"
      :height="$options.progressBarHeight"
    />
    <div class="gl-text-gray-400 gl-mb-1" data-testid="card-description">{{ description }}</div>
    <template v-if="displayMeta">
      <div
        v-for="feature in featureMeta"
        :key="feature.title"
        class="gl-display-flex gl-align-items-center gl-mt-2"
        data-testid="card-meta-row"
      >
        <devops-adoption-table-cell-flag :enabled="feature.adopted" class="gl-mr-3" />
        <span class="gl-text-gray-600 gl-font-sm" data-testid="card-meta-row-title">{{
          feature.title
        }}</span>
      </div>
    </template>
  </div>
</template>
