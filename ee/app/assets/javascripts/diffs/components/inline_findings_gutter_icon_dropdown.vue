<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { GlIcon } from '@gitlab/ui';
import { n__ } from '~/locale';
import { getSeverity } from '~/ci/reports/utils';
import { SAST_SCALE_KEY, CODE_QUALITY_SCALE_KEY } from '~/ci/reports/constants';
import InlineFindingsDropdown from './inline_findings_dropdown.vue';
import { scaleFindings } from './inline_findings_gutter_icon_utils';

const inlineFindingsCountThreshold = 3;
const codeQualityGroupHeading = (elem) =>
  n__(
    'InlineFindings|1 Code Quality finding detected',
    'InlineFindings|%d Code Quality findings detected',
    elem.length,
  );

const sastGroupHeading = (elem) =>
  n__(
    'InlineFindings|1 SAST finding detected',
    'InlineFindings|%d SAST findings detected',
    elem.length,
  );

export default {
  components: {
    GlIcon,
    InlineFindingsDropdown,
  },
  props: {
    filePath: {
      type: String,
      required: true,
    },
    codeQuality: {
      type: Array,
      required: false,
      default: () => [],
    },
    sast: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isHoveringFirstIcon: false,
    };
  },
  computed: {
    scaledCodeQuality() {
      return getSeverity(this.codeQuality.map((e) => scaleFindings(e, CODE_QUALITY_SCALE_KEY)));
    },
    scaledSast() {
      return getSeverity(this.sast.map((e) => scaleFindings(e, SAST_SCALE_KEY)));
    },
    flatFindings() {
      return this.scaledCodeQuality.concat(this.scaledSast);
    },
    groupedFindings() {
      const groupedFindings = [];

      if (this.codeQuality.length > 0) {
        groupedFindings.push({
          name: codeQualityGroupHeading(this.codeQuality),
          items: this.scaledCodeQuality,
        });
      }

      if (this.sast.length > 0) {
        groupedFindings.push({
          name: sastGroupHeading(this.sast),

          items: this.scaledSast,
        });
      }

      const allLineFindings = this.flatFindings;

      // Enhance each finding with the correct index and action
      allLineFindings.forEach((finding, index) => {
        /* eslint-disable no-param-reassign */
        finding.action = () => this.toggleDrawer(allLineFindings, index);
        // enhance to match GlDisclosureDropdown validator
        // https://gitlab-org.gitlab.io/gitlab-ui/?path=/docs/base-new-dropdowns-disclosure--docs#setting-disclosure-dropdown-items
        finding.text = finding.description;
        /* eslint-enable no-param-reassign */
      });

      return groupedFindings.map((group) => ({
        ...group,
        items: group.items.map((item) => allLineFindings.find((f) => f === item)),
      }));
    },
    showMoreCount() {
      return this.moreCount && this.isHoveringFirstIcon;
    },
    moreCount() {
      return this.flatFindings.length > inlineFindingsCountThreshold
        ? this.flatFindings.length - inlineFindingsCountThreshold
        : 0;
    },
    firstItem() {
      return { ...this.flatFindings[0], filePath: this.filePath };
    },
    inlineFindingsSubItems() {
      return this.flatFindings.slice(1, inlineFindingsCountThreshold);
    },
  },
  methods: {
    toggleDrawer(findings, index) {
      this.setDrawer({ findings, index });
    },
    ...mapActions('findingsDrawer', ['setDrawer']),
  },
};
</script>

<template>
  <div v-if="flatFindings.length" class="gl-relative">
    <div class="gl-inline-flex">
      <span ref="inlineFindingsIcon">
        <inline-findings-dropdown
          :items="groupedFindings"
          :icon-id="`${filePath}-${firstItem.line}`"
          :icon-key="firstItem.description"
          :icon-name="firstItem.name"
          :icon-class="firstItem.class"
          @mouseenter="isHoveringFirstIcon = true"
          @mouseleave="isHoveringFirstIcon = false"
        />
      </span>
      <span class="inline-findings-transition-container gl-inline-flex">
        <transition-group name="icons">
          <!--
            The TransitionGroup Component will only apply its classes when first-level children are added/removed to the DOM.
            So to make TransitionGroup work there is no other way to use v-if-with-v-for in this case.
          -->
          <!-- eslint-disable vue/no-use-v-if-with-v-for -->

          <gl-icon
            v-for="item in inlineFindingsSubItems"
            v-if="isHoveringFirstIcon"
            :key="item.description"
            :name="item.name"
            :class="item.class"
            class="gl-hover-cursor-pointer gl-relative gl-top-1 inline-findings-severity-icon gl-absolute gl-left-0"
          />
          <!-- eslint-enable -->
        </transition-group>
        <transition name="more-count">
          <div
            v-if="showMoreCount"
            class="more-count gl-px-2 gl-w-auto gl-absolute gl-left-0 gl-relative gl-top-1"
          >
            <p
              data-testid="inline-findings-more-count"
              class="gl-mb-0 gl-block gl-w-3 more-count-copy-dropdown"
            >
              {{ moreCount }}
            </p>
          </div>
        </transition>
      </span>
    </div>
  </div>
</template>
