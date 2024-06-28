<script>
import {
  GlAccordion,
  GlAccordionItem,
  GlButton,
  GlCard,
  GlCollapsibleListbox,
  GlFormGroup,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';

export default {
  name: 'SubscriptionGroupSelector',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlButton,
    GlCard,
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    eligibleGroups: {
      type: Array,
      required: false,
      default: () => [],
    },
    plansData: {
      type: Object,
      required: true,
    },
    rootUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      selectedGroupId: null,
      isValidated: false,
      isLoading: false,
    };
  },
  computed: {
    selectedGroup() {
      return this.eligibleGroups.find((group) => group.id === this.selectedGroupId);
    },
    toggleText() {
      return this.selectedGroup
        ? this.selectedGroup.name
        : this.$options.i18n.groupSelection.placeholder;
    },
    groupOptions() {
      return this.eligibleGroups.map(({ id, name }) => ({ text: name, value: id }));
    },
    hasValidGroupSelection() {
      return Boolean(this.selectedGroupId);
    },
    groupValidationError() {
      if (!this.isValidated || this.hasValidGroupSelection) {
        return null;
      }
      return this.$options.i18n.groupSelection.validationMessage;
    },
    planName() {
      switch (this.plansData.code) {
        case 'premium':
          return s__('BillingPlans|Premium');
        case 'ultimate':
          return s__('BillingPlans|Ultimate');
        default:
          return this.plansData.name;
      }
    },
    title() {
      return sprintf(
        s__('SubscriptionGroupsNew|Select a group for your %{planName} subscription'),
        { planName: this.planName },
      );
    },
  },
  methods: {
    handleGroupSelection(value) {
      this.selectedGroupId = value;
    },
    continueWithSelection() {
      this.isValidated = true;

      if (!this.hasValidGroupSelection) {
        return;
      }

      this.isLoading = true;
      this.navigateToPurchaseFlow(this.selectedGroupId);
    },
    navigateToPurchaseFlow(groupId) {
      // We should always have a purchase link available. In the unlikely scenario where
      // we don't, we want to know about it, so let's report the error to Sentry
      if (!this.plansData.purchase_link?.href) {
        this.reportError(`Missing purchase link for plan ${JSON.stringify(this.plansData)}`);
        return;
      }

      const purchaseLink = `${this.plansData.purchase_link.href}&gl_namespace_id=${groupId}`;
      visitUrl(purchaseLink);
    },
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
  },
  i18n: {
    groupSelection: {
      placeholder: __('Select a group'),
      label: __('Group'),
      description: s__('Checkout|Your subscription will be applied to this group'),
      validationMessage: s__('SubscriptionGroupsNew|Select a group for your subscription'),
    },
    accordion: {
      title: s__(`SubscriptionGroupsNew|Why can't I find my group?`),
      description: s__(
        'SubscriptionGroupsNew|Your group will only be displayed in the list above if:',
      ),
      reasonOne: s__(`SubscriptionGroupsNew|You're assigned the Owner role of the group`),
      reasonTwo: s__('SubscriptionGroupsNew|The group is a top-level group on a Free tier'),
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-justify-center">
    <div class="gl-max-w-88">
      <h2>{{ title }}</h2>
      <gl-card class="gl-max-w-62 gl-mx-auto gl-p-5 gl-mt-10">
        <label class="gl-block gl-mb-1">{{ $options.i18n.groupSelection.label }}</label>
        <span class="gl-text-secondary">{{ $options.i18n.groupSelection.description }}</span>
        <gl-form-group
          :state="!groupValidationError"
          :invalid-feedback="groupValidationError"
          data-testid="group-selector"
        >
          <gl-collapsible-listbox
            v-model="selectedGroupId"
            block
            fluid-width
            :items="groupOptions"
            :toggle-text="toggleText"
            category="secondary"
            :variant="groupValidationError ? 'danger' : 'default'"
            @select="handleGroupSelection"
          />
        </gl-form-group>
        <gl-accordion :header-level="3">
          <gl-accordion-item :title="$options.i18n.accordion.title">
            {{ $options.i18n.accordion.description }}
            <ul class="gl-mt-4">
              <li>{{ $options.i18n.accordion.reasonOne }}</li>
              <li>{{ $options.i18n.accordion.reasonTwo }}</li>
            </ul>
          </gl-accordion-item>
        </gl-accordion>
        <gl-button
          class="gl-mt-5 gl-w-full"
          category="primary"
          variant="confirm"
          :loading="isLoading"
          @click="continueWithSelection"
          >{{ __('Continue') }}</gl-button
        >
      </gl-card>
    </div>
  </div>
</template>
