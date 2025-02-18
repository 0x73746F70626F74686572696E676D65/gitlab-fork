<script>
import { GlAlert, GlLink, GlSprintf, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import { PROMO_URL } from '~/lib/utils/url_utility';
import { PROMO_CODE_OFFER_TEXT, PROMO_CODE_TERMS_LINK } from 'ee/subscriptions/new/constants';
import formattingMixins from '../../formatting_mixins';

export default {
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    GlLoadingIcon,
  },
  mixins: [formattingMixins, Tracking.mixin()],
  PROMO_CODE_OFFER_TEXT,
  PROMO_CODE_TERMS_LINK,
  computed: {
    ...mapState(['startDate', 'taxRate', 'numberOfUsers', 'isInvoicePreviewLoading']),
    ...mapGetters([
      'selectedPlanText',
      'endDate',
      'totalExVat',
      'vat',
      'totalAmount',
      'usersPresent',
      'showAmount',
      'discount',
      'showPromotionalOfferText',
      'unitPrice',
    ]),
    taxAmount() {
      return this.taxRate ? this.formatAmount(this.vat, this.showAmount) : '–';
    },
    taxLine() {
      return `${this.$options.i18n.tax} ${this.$options.i18n.taxNote}`;
    },
  },
  i18n: {
    selectedPlanText: s__('Checkout|%{selectedPlanText}'),
    numberOfUsers: s__('Checkout|(x%{numberOfUsers})'),
    pricePerUserPerYear: s__('Checkout|$%{pricePerUserPerYear} per user per year'),
    dates: s__('Checkout|%{startDate} - %{endDate}'),
    subtotal: s__('Checkout|Subtotal'),
    discount: s__('Checkout|Discount'),
    tax: s__('Checkout|Tax'),
    taxNote: s__('Checkout|(may be %{linkStart}charged upon purchase%{linkEnd})'),
    total: s__('Checkout|Total'),
  },
  taxHelpUrl: `${PROMO_URL}/handbook/tax/#indirect-taxes-management`,
};
</script>
<template>
  <div>
    <div class="gl-display-flex gl-justify-content-space-between gl-font-bold gl-mb-3">
      <div data-testid="selected-plan">
        {{ sprintf($options.i18n.selectedPlanText, { selectedPlanText }) }}
        <span v-if="usersPresent" data-testid="number-of-users">{{
          sprintf($options.i18n.numberOfUsers, { numberOfUsers })
        }}</span>
      </div>
      <gl-loading-icon v-if="isInvoicePreviewLoading" inline class="gl-my-auto gl-ml-3" />
      <div v-else class="gl-ml-3" data-testid="amount">
        {{ formatAmount(totalExVat, showAmount) }}
      </div>
    </div>
    <div v-if="!isInvoicePreviewLoading" class="gl-text-gray-500" data-testid="per-user">
      {{
        sprintf($options.i18n.pricePerUserPerYear, {
          pricePerUserPerYear: unitPrice.toLocaleString(),
        })
      }}
    </div>
    <div v-if="!isInvoicePreviewLoading" class="gl-text-gray-500" data-testid="dates">
      {{
        sprintf($options.i18n.dates, {
          startDate: formatDate(startDate),
          endDate: formatDate(endDate),
        })
      }}
    </div>
    <gl-alert
      v-if="showPromotionalOfferText"
      data-testid="promotional-offer-text"
      :dismissible="false"
      class="gl-mt-5"
    >
      <gl-sprintf :message="$options.PROMO_CODE_OFFER_TEXT">
        <template #link="{ content }">
          <gl-link :href="$options.PROMO_CODE_TERMS_LINK" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <slot name="promo-code"></slot>
    <div>
      <div class="gl-border-b-1 gl-border-b-gray-100 gl-border-b-solid gl-my-5"></div>
      <div class="gl-display-flex gl-justify-content-space-between gl-text-gray-500 gl-mb-2">
        <div>{{ $options.i18n.subtotal }}</div>
        <gl-loading-icon v-if="isInvoicePreviewLoading" inline class="gl-my-auto" />
        <div v-else data-testid="total-ex-vat">{{ formatAmount(totalExVat, showAmount) }}</div>
      </div>
      <div
        v-if="discount"
        class="gl-display-flex gl-justify-content-space-between gl-text-gray-500 gl-mb-2"
      >
        <div>{{ $options.i18n.discount }}</div>
        <gl-loading-icon v-if="isInvoicePreviewLoading" inline class="gl-my-auto" />
        <div v-else data-testid="discount">{{ formatAmount(discount, showAmount) }}</div>
      </div>
      <div class="gl-display-flex gl-justify-content-space-between gl-text-gray-500">
        <div data-testid="tax-info-line">
          <gl-sprintf :message="taxLine">
            <template #link="{ content }">
              <gl-link
                class="gl-underline gl-text-gray-500"
                :href="$options.taxHelpUrl"
                target="_blank"
                data-testid="tax-help-link"
                @click="track('click_button', { label: 'tax_link' })"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </div>
        <gl-loading-icon v-if="isInvoicePreviewLoading" inline class="gl-my-auto" />
        <div v-else data-testid="vat">{{ taxAmount }}</div>
      </div>
    </div>
    <div class="gl-border-b-1 gl-border-b-gray-100 gl-border-b-solid gl-my-5"></div>
    <div class="gl-display-flex gl-justify-content-space-between gl-font-lg gl-font-bold">
      <div>{{ $options.i18n.total }}</div>
      <gl-loading-icon v-if="isInvoicePreviewLoading" inline class="gl-my-auto" />
      <div v-else data-testid="total-amount">
        {{ formatAmount(totalAmount, showAmount) }}
      </div>
    </div>
  </div>
</template>
