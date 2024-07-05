<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

export default {
  i18n: {
    title: s__('Observability|Usage breakdown'),
    subtitle: s__('Observability|Includes Logs, Traces and Metrics. %{learnMoreLink}'),
    learnMoreLinkText: __('Learn more.'),
    eventsTotal: s__('Observability|%{events} events'),
  },
  docsLink: `${DOCS_URL_IN_EE_DIR}/operations`,
  components: {
    SectionedPercentageBar,
    GlSprintf,
    GlLink,
    NumberToHumanSize,
  },
  props: {
    usageData: {
      type: Object,
      required: true,
    },
  },
  computed: {
    eventsData() {
      return Object.values(this.usageData.events)[0];
    },
    storageData() {
      return Object.values(this.usageData.storage)[0];
    },
    storageUsage() {
      return this.storageData.aggregated_total;
    },
    eventsUsage() {
      return this.eventsData.aggregated_total;
    },
    storageSectionedUsage() {
      const data = this.storageData.aggregated_per_feature;
      return Object.entries(data).map(([key, value]) => ({
        id: key,
        label: key,
        value,
        formattedValue: numberToHumanSize(value),
      }));
    },
    eventsSectionedUsage() {
      const data = this.eventsData.aggregated_per_feature;
      return Object.entries(data).map(([key, value]) => ({
        id: key,
        label: key,
        value,
        formattedValue: value,
      }));
    },
  },
};
</script>

<template>
  <section>
    <div>
      <div class="gl-flex gl-justify-between">
        <div>
          <h4 class="gl-text-lg gl-mb-3 gl-mt-0">{{ $options.i18n.title }}</h4>
          <p>
            <gl-sprintf :message="$options.i18n.subtitle">
              <template #learnMoreLink>
                <gl-link target="_blank" :href="$options.docsLink">
                  <span>{{ $options.i18n.learnMoreLinkText }}</span>
                </gl-link>
              </template>
            </gl-sprintf>
          </p>
        </div>
        <div
          v-if="storageData"
          data-testid="total-storage-usage"
          class="gl-m-0 gl-text-size-h-display gl-font-bold gl-whitespace-nowrap"
        >
          <number-to-human-size :value="storageUsage" />
        </div>
      </div>

      <sectioned-percentage-bar
        v-if="storageData"
        data-testid="sectioned-storage-usage"
        class="gl-mt-5"
        :sections="storageSectionedUsage"
      />

      <div
        v-if="eventsData"
        data-testid="total-events-usage"
        class="gl-my-6 gl-text-size-h-display gl-font-bold gl-whitespace-nowrap gl-flex gl-flex-col gl-items-end"
      >
        <gl-sprintf :message="$options.i18n.eventsTotal">
          <template #events>{{ eventsUsage }}</template>
        </gl-sprintf>
      </div>

      <sectioned-percentage-bar
        v-if="eventsData"
        data-testid="sectioned-events-usage"
        class="gl-mt-5"
        :sections="eventsSectionedUsage"
      />
    </div>
  </section>
</template>
