<script>
import { GlLink, GlButton, GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { GEO_REPLICATION_SUPPORTED_TYPES_URL } from 'ee/geo_sites/constants';
import { s__ } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import GeoSiteReplicationDetailsResponsive from './geo_site_replication_details_responsive.vue';
import GeoSiteReplicationStatusMobile from './geo_site_replication_status_mobile.vue';

export default {
  name: 'GeoSiteReplicationDetails',
  i18n: {
    replicationDetails: s__('Geo|Replication Details'),
    naVerificationHelpText: s__(
      'Geo|%{boldStart}Not applicable%{boldEnd}: Geo does not verify this component yet. See the %{linkStart}data types we plan to support%{linkEnd}.',
    ),
  },
  components: {
    GlLink,
    GlButton,
    GlSprintf,
    GeoSiteReplicationDetailsResponsive,
    GeoSiteReplicationStatusMobile,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      collapsed: false,
    };
  },
  computed: {
    ...mapGetters(['verificationInfo', 'syncInfo', 'sortedReplicableTypes']),
    replicationItems() {
      const syncInfoData = this.syncInfo(this.site.id);
      const verificationInfoData = this.verificationInfo(this.site.id);

      return this.sortedReplicableTypes.map((replicable) => {
        const replicableSyncInfo = syncInfoData.find((r) => r.title === replicable.titlePlural);

        const replicableVerificationInfo = verificationInfoData.find(
          (r) => r.title === replicable.titlePlural,
        );

        return {
          dataTypeTitle: replicable.dataTypeTitle,
          component: replicable.titlePlural,
          syncValues: replicableSyncInfo ? replicableSyncInfo.values : null,
          verificationValues: replicableVerificationInfo ? replicableVerificationInfo.values : null,
          replicationView: this.getReplicationView(replicable),
        };
      });
    },
    chevronIcon() {
      return this.collapsed ? 'chevron-right' : 'chevron-down';
    },
    hasNAVerificationType() {
      return this.replicationItems.some((item) => !item.verificationValues);
    },
  },
  methods: {
    collapseSection() {
      this.collapsed = !this.collapsed;
    },
    getReplicationView(replicable) {
      if (replicable.noReplicationView) {
        return null;
      }

      return joinPaths(
        gon.relative_url_root || '/',
        `/admin/geo/sites/${this.site.id}/replication/${replicable.namePlural}`,
      );
    },
  },
  GEO_REPLICATION_SUPPORTED_TYPES_URL,
};
</script>

<template>
  <div>
    <div class="gl-py-5 gl-border-b gl-border-t">
      <gl-button
        class="gl-mr-1 gl-p-0!"
        category="tertiary"
        variant="confirm"
        :icon="chevronIcon"
        @click="collapseSection"
      >
        {{ $options.i18n.replicationDetails }}
      </gl-button>
    </div>
    <div v-if="!collapsed">
      <geo-site-replication-details-responsive
        class="gl-hidden md:gl-block"
        :site-id="site.id"
        :replication-items="replicationItems"
        data-testid="geo-replication-details-desktop"
      />
      <geo-site-replication-details-responsive
        class="md:!gl-hidden"
        :site-id="site.id"
        :replication-items="replicationItems"
        data-testid="geo-replication-details-mobile"
      >
        <template #title="{ translations }">
          <span class="gl-font-bold">{{ translations.component }}</span>
          <span class="gl-font-bold">{{ translations.status }}</span>
        </template>
        <template #default="{ item, translations }">
          <div class="gl-mr-5" data-testid="replicable-component">
            <gl-link v-if="item.replicationView" :href="item.replicationView">{{
              item.component
            }}</gl-link>
            <span v-else>{{ item.component }}</span>
          </div>
          <geo-site-replication-status-mobile :item="item" :translations="translations" />
        </template>
      </geo-site-replication-details-responsive>
      <div v-if="hasNAVerificationType" class="gl-mt-4">
        <gl-sprintf :message="$options.i18n.naVerificationHelpText">
          <template #bold="{ content }">
            <span class="gl-font-bold">{{ content }} </span>
          </template>
          <template #link="{ content }">
            <gl-link
              data-testid="naVerificationHelpLink"
              :href="$options.GEO_REPLICATION_SUPPORTED_TYPES_URL"
              target="_blank"
              >{{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
    </div>
  </div>
</template>
