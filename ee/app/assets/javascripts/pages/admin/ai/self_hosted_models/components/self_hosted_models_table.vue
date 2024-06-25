<script>
import { GlTableLite, GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';

export default {
  name: 'SelfHostedModelsTable',
  components: {
    GlTableLite,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
  },
  props: {
    models: {
      type: Array,
      required: true,
    },
    basePath: {
      type: String,
      required: true,
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Name'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model',
      label: __('Model'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
    {
      key: 'endpoint',
      label: s__('AdminSelfHostedModels|Endpoint'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center gl-text-ellipsis',
    },
    {
      key: 'has_api_key',
      label: __('API key'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
    {
      key: 'edit',
      label: '',
      thClass: 'w-15p',
      tdClass: 'gl-content-center gl-text-right',
    },
  ],
  methods: {
    editModelItem(model) {
      return {
        text: __('Edit'),
        to: `${this.basePath}/${getIdFromGraphQLId(model.id)}/edit`,
      };
    },
    deleteModelItem() {
      /** TODO: implement delete functionality https://gitlab.com/gitlab-org/gitlab/-/issues/463137 */
      return {
        text: s__('AdminSelfHostedModels|Delete model'),
        extraAttrs: {
          class: 'text-danger',
        },
      };
    },
  },
};
</script>
<template>
  <gl-table-lite
    data-testid="self-hosted-model-table"
    :fields="$options.fields"
    :items="models"
    stacked="md"
    :hover="true"
    :selectable="false"
  >
    <template #cell(has_api_key)="{ item }">
      <gl-icon
        v-if="item.hasApiToken"
        :aria-label="s__('AdminSelfHostedModels|Model has API key')"
        name="check-xs"
      />
      <gl-icon
        v-else
        :aria-label="s__('AdminSelfHostedModels|Model does not have API key')"
        name="close-xs"
      />
    </template>
    <template #cell(edit)="{ item }">
      <div>
        <gl-disclosure-dropdown
          category="tertiary"
          variant="default"
          size="small"
          icon="ellipsis_v"
          :no-caret="true"
        >
          <gl-disclosure-dropdown-item :item="editModelItem(item)" />
          <gl-disclosure-dropdown-item :item="deleteModelItem()" />
        </gl-disclosure-dropdown>
      </div>
    </template>
  </gl-table-lite>
</template>
