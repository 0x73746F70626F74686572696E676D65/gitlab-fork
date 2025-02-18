<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { ACTION_TYPES } from '../constants';
import GeoReplicableStatus from './geo_replicable_status.vue';
import GeoReplicableTimeAgo from './geo_replicable_time_ago.vue';

export default {
  name: 'GeoReplicableItem',
  i18n: {
    unknown: __('Unknown'),
    nA: __('Not applicable.'),
    resync: s__('Geo|Resync'),
    reverify: s__('Geo|Reverify'),
    lastVerified: s__('Geo|Last time verified'),
  },
  components: {
    GlButton,
    GeoReplicableTimeAgo,
    GeoReplicableStatus,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    name: {
      type: String,
      required: true,
    },
    registryId: {
      type: [String, Number],
      required: true,
    },
    syncStatus: {
      type: String,
      required: false,
      default: '',
    },
    lastSynced: {
      type: String,
      required: false,
      default: '',
    },
    lastVerified: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    ...mapState(['verificationEnabled']),
    timeAgoArray() {
      return [
        {
          label: capitalizeFirstCharacter(this.syncStatus),
          dateString: this.lastSynced,
          defaultText: this.$options.i18n.unknown,
        },
        {
          label: this.$options.i18n.lastVerified,
          dateString: this.lastVerified,
          defaultText: this.verificationEnabled
            ? this.$options.i18n.unknown
            : this.$options.i18n.nA,
        },
      ];
    },
  },
  methods: {
    ...mapActions(['initiateReplicableAction']),
  },
  actionTypes: ACTION_TYPES,
};
</script>

<template>
  <div class="gl-border-b gl-p-5">
    <div
      class="geo-replicable-item-grid gl-display-grid gl-align-items-center gl-pb-4"
      data-testid="replicable-item-header"
    >
      <geo-replicable-status :status="syncStatus" />
      <span class="gl-font-bold">{{ name }}</span>
      <div>
        <gl-button
          data-testid="geo-resync-item"
          size="small"
          @click="
            initiateReplicableAction({ registryId, name, action: $options.actionTypes.RESYNC })
          "
        >
          {{ $options.i18n.resync }}
        </gl-button>
        <gl-button
          v-if="verificationEnabled"
          data-testid="geo-reverify-item"
          size="small"
          @click="
            initiateReplicableAction({ registryId, name, action: $options.actionTypes.REVERIFY })
          "
        >
          {{ $options.i18n.reverify }}
        </gl-button>
      </div>
    </div>
    <div class="gl-display-flex gl-align-items-center gl-flex-wrap">
      <geo-replicable-time-ago
        v-for="(timeAgo, index) in timeAgoArray"
        :key="index"
        :label="timeAgo.label"
        :date-string="timeAgo.dateString"
        :default-text="timeAgo.defaultText"
        :show-divider="index !== timeAgoArray.length - 1"
      />
    </div>
  </div>
</template>
