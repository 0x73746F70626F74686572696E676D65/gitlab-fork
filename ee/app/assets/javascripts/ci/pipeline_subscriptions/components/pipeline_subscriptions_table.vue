<script>
import { GlButton, GlCard, GlIcon, GlLink, GlTable, GlTooltipDirective } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import PipelineSubscriptionsForm from './pipeline_subscriptions_form.vue';

export default {
  name: 'PipelineSubscriptionsTable',
  i18n: {
    newBtnText: s__('PipelineSubscriptions|Add new'),
    deleteTooltip: s__('PipelineSubscriptions|Delete subscription'),
  },
  fields: [
    {
      key: 'project',
      label: __('Project'),
      columnClass: 'gl-w-6/10',
      tdClass: '!gl-align-middle',
    },
    {
      key: 'namespace',
      label: __('Namespace'),
      columnClass: 'gl-w-3/10',
      tdClass: '!gl-align-middle',
    },
    {
      key: 'actions',
      label: '',
      columnClass: 'gl-w-2/10',
      tdClass: 'gl-text-right',
    },
  ],
  components: {
    GlButton,
    GlCard,
    GlIcon,
    GlLink,
    GlTable,
    PipelineSubscriptionsForm,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    count: {
      type: Number,
      required: true,
    },
    emptyText: {
      type: String,
      required: true,
    },
    subscriptions: {
      type: Array,
      required: true,
    },
    showActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    title: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isAddNewClicked: false,
    };
  },
  computed: {
    showForm() {
      return this.showActions && this.isAddNewClicked;
    },
  },
};
</script>

<template>
  <gl-card
    class="gl-new-card"
    header-class="gl-new-card-header"
    body-class="gl-new-card-body gl-px-0"
  >
    <template #header>
      <div class="gl-new-card-title-wrapper gl-flex-direction-column">
        <h3 class="gl-new-card-title">
          <span data-testid="subscription-title">{{ title }}</span>
          <div class="gl-new-card-count">
            <gl-icon name="pipeline" class="gl-mr-2" />
            <span data-testid="subscription-count">{{ count }}</span>
          </div>
        </h3>
      </div>
      <div v-if="showActions" class="gl-new-card-actions">
        <gl-button
          v-if="!isAddNewClicked"
          size="small"
          data-testid="add-new-subscription-btn"
          @click="isAddNewClicked = true"
        >
          {{ $options.i18n.newBtnText }}
        </gl-button>
      </div>
    </template>

    <pipeline-subscriptions-form
      v-if="showForm"
      @canceled="isAddNewClicked = false"
      @addSubscriptionSuccess="$emit('refetchSubscriptions')"
    />

    <gl-table
      :fields="$options.fields"
      :items="subscriptions"
      :empty-text="emptyText"
      show-empty
      stacked="md"
      fixed
    >
      <template #table-colgroup="{ fields }">
        <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
      </template>

      <template #cell(project)="{ item }">
        <gl-link :href="item.project.webUrl">{{ item.project.name }}</gl-link>
      </template>

      <template #cell(namespace)="{ item }">
        <span data-testid="subscription-namespace">{{ item.project.namespace.name }}</span>
      </template>

      <template #cell(actions)="{ item }">
        <gl-button
          v-if="showActions"
          v-gl-tooltip
          :title="$options.i18n.deleteTooltip"
          category="tertiary"
          size="small"
          icon="remove"
          data-testid="delete-subscription-btn"
          @click="$emit('showModal', item.id)"
        />
      </template>
    </gl-table>
  </gl-card>
</template>
