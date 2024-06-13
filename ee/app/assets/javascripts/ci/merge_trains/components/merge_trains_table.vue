<script>
import { GlLink, GlTable } from '@gitlab/ui';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';

export default {
  name: 'MergeTrainsTable',
  fields: [
    {
      key: 'mr',
      label: __('Merge request'),
      thClass: 'gl-border-t-none!',
      columnClass: 'gl-w-90p',
    },
    {
      key: 'actions',
      label: '',
      thClass: 'gl-border-t-none!',
      tdClass: 'gl-text-right',
      columnClass: 'gl-w-10p',
    },
  ],
  components: {
    CiIcon,
    GlLink,
    GlTable,
    UserAvatarLink,
  },
  props: {
    train: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      items: [],
    };
  },
  computed: {
    cars() {
      return this.train?.cars?.nodes || [];
    },
  },
  methods: {
    buildTimeAgoString(createdAt) {
      const timeAgo = getTimeago().format(createdAt);

      return sprintf(__('Added %{timeAgo} by'), { timeAgo });
    },
  },
};
</script>

<template>
  <gl-table
    :items="cars"
    :fields="$options.fields"
    :empty-text="__('There are no merge trains to show.')"
    show-empty
    stacked="md"
  >
    <template #table-colgroup="{ fields }">
      <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
    </template>

    <template #cell(mr)="{ item }">
      <ci-icon v-if="item.pipeline" :status="item.pipeline.detailedStatus" />
      <gl-link :href="item.mergeRequest.webPath" class="gl-underline gl-ml-3">
        {{ item.mergeRequest.title }}
      </gl-link>
      <div class="gl-ml-3 gl-inline-block">
        <span data-testid="added-to-train-text">
          {{ buildTimeAgoString(item.createdAt) }}
        </span>
        <user-avatar-link
          :link-href="item.user.webPath"
          :img-src="item.user.avatarUrl"
          :img-size="16"
          :img-alt="item.user.name"
          :tooltip-text="item.user.name"
          class="gl-ml-1"
        />
      </div>
    </template>
  </gl-table>
</template>
